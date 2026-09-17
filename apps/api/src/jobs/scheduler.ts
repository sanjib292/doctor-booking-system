import { CronJob } from 'cron';
import { prisma } from '../config/database';
import { sendPushNotification } from '../config/firebase';
import { AppointmentStatus, NotificationType } from '@prisma/client';
import { logger } from '../common/utils/logger';

function startOfDay(d: Date): Date {
  const r = new Date(d); r.setHours(0,0,0,0); return r;
}
function endOfDay(d: Date): Date {
  const r = new Date(d); r.setHours(23,59,59,999); return r;
}

// Release expired slot locks every minute
const slotLockReleaseJob = new CronJob('*/1 * * * *', async () => {
  try {
    const { count } = await prisma.timeSlot.updateMany({
      where: { status: 'LOCKED', lockExpiresAt: { lt: new Date() } },
      data: { status: 'AVAILABLE', lockedAt: null, lockedBy: null, lockExpiresAt: null },
    });
    if (count > 0) logger.debug(`Released ${count} expired slot locks`);
  } catch (err) {
    logger.error('slotLockReleaseJob error:', err);
  }
});

// Send 24-hour appointment reminders (run every hour)
const reminder24hJob = new CronJob('0 * * * *', async () => {
  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);

    const appointments = await prisma.appointment.findMany({
      where: {
        date: { gte: startOfDay(tomorrow), lte: endOfDay(tomorrow) },
        status: AppointmentStatus.CONFIRMED,
        isPatientReminded24h: false,
      },
      include: {
        patient: { select: { fcmToken: true, name: true } },
        doctor: { select: { name: true } },
      },
    });

    for (const appt of appointments) {
      if (appt.patient.fcmToken) {
        const sent = await sendPushNotification(
          appt.patient.fcmToken,
          'Appointment Reminder',
          `Your appointment with Dr. ${appt.doctor.name} is tomorrow at ${appt.startTime}`,
          { appointmentId: appt.id, type: NotificationType.BOOKING_REMINDER_24H },
        );

        if (sent) {
          await prisma.appointment.update({
            where: { id: appt.id },
            data: { isPatientReminded24h: true },
          });

          await prisma.notification.create({
            data: {
              userId: appt.patientId,
              type: NotificationType.BOOKING_REMINDER_24H,
              title: 'Appointment Reminder',
              body: `Your appointment with Dr. ${appt.doctor.name} is tomorrow at ${appt.startTime}`,
              data: { appointmentId: appt.id },
            },
          });
        }
      }
    }

    logger.info(`24h reminder job: processed ${appointments.length} appointments`);
  } catch (err) {
    logger.error('reminder24hJob error:', err);
  }
});

// Send 1-hour appointment reminders (run every 15 minutes)
const reminder1hJob = new CronJob('*/15 * * * *', async () => {
  try {
    const oneHourLater = new Date(Date.now() + 60 * 60 * 1000);
    const oneHourFifteenLater = new Date(Date.now() + 75 * 60 * 1000);

    const targetDate = startOfDay(oneHourLater);
    const fromTime = oneHourLater.toTimeString().slice(0, 5);
    const toTime = oneHourFifteenLater.toTimeString().slice(0, 5);

    const appointments = await prisma.appointment.findMany({
      where: {
        date: targetDate,
        startTime: { gte: fromTime, lte: toTime },
        status: AppointmentStatus.CONFIRMED,
        isPatientReminded1h: false,
      },
      include: {
        patient: { select: { fcmToken: true, id: true } },
        doctor: { select: { name: true } },
      },
    });

    for (const appt of appointments) {
      if (appt.patient.fcmToken) {
        const sent = await sendPushNotification(
          appt.patient.fcmToken,
          'Appointment in 1 Hour',
          `Your appointment with Dr. ${appt.doctor.name} starts at ${appt.startTime}`,
          { appointmentId: appt.id, type: NotificationType.BOOKING_REMINDER_1H },
        );

        if (sent) {
          await prisma.appointment.update({
            where: { id: appt.id },
            data: { isPatientReminded1h: true },
          });

          await prisma.notification.create({
            data: {
              userId: appt.patient.id,
              type: NotificationType.BOOKING_REMINDER_1H,
              title: 'Appointment in 1 Hour',
              body: `Your appointment with Dr. ${appt.doctor.name} starts at ${appt.startTime}`,
              data: { appointmentId: appt.id },
            },
          });
        }
      }
    }
  } catch (err) {
    logger.error('reminder1hJob error:', err);
  }
});

// Clean up old OTPs daily at midnight
const cleanOtpJob = new CronJob('0 0 * * *', async () => {
  try {
    const { count } = await prisma.otpCode.deleteMany({
      where: { OR: [{ isUsed: true }, { expiresAt: { lt: new Date() } }] },
    });
    logger.info(`Cleaned ${count} expired OTP records`);
  } catch (err) {
    logger.error('cleanOtpJob error:', err);
  }
});

// Clean up revoked refresh tokens older than 30 days
const cleanTokensJob = new CronJob('0 2 * * *', async () => {
  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const { count } = await prisma.refreshToken.deleteMany({
      where: { isRevoked: true, expiresAt: { lt: new Date() } },
    });
    logger.info(`Cleaned ${count} expired refresh tokens`);
  } catch (err) {
    logger.error('cleanTokensJob error:', err);
  }
});

export function startScheduler(): void {
  slotLockReleaseJob.start();
  reminder24hJob.start();
  reminder1hJob.start();
  cleanOtpJob.start();
  cleanTokensJob.start();
  logger.info('Scheduler started — all cron jobs active');
}

export function stopScheduler(): void {
  slotLockReleaseJob.stop();
  reminder24hJob.stop();
  reminder1hJob.stop();
  cleanOtpJob.stop();
  cleanTokensJob.stop();
  logger.info('Scheduler stopped');
}
