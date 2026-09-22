import { env } from '../../config/env';

const logger = { info: console.log, warn: console.warn, error: console.error };

async function send(to: string, subject: string, html: string) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    logger.info(`[EMAIL] No RESEND_API_KEY set — skipping. To: ${to} | ${subject}`);
    return;
  }

  const from = env.EMAIL_FROM ?? 'DoctorBook <onboarding@resend.dev>';

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from, to: [to], subject, html }),
    });
    const data = await res.json() as any;
    if (!res.ok) {
      logger.error(`[EMAIL] Resend API error (${res.status}): ${JSON.stringify(data)}`);
    } else {
      logger.info(`[EMAIL] Sent to ${to}: ${subject} (id=${data.id})`);
    }
  } catch (err) {
    logger.error(`[EMAIL] Failed to send to ${to}: ${err}`);
  }
}

function base(title: string, body: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  body { margin:0; padding:0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background:#f4f7fb; }
  .wrap { max-width:560px; margin:32px auto; background:#fff; border-radius:16px; overflow:hidden; box-shadow:0 2px 12px rgba(0,0,0,.08); }
  .header { background:linear-gradient(135deg,#2563EB,#1e40af); padding:28px 32px; }
  .header h1 { margin:0; color:#fff; font-size:20px; font-weight:700; }
  .header p { margin:6px 0 0; color:rgba(255,255,255,.8); font-size:13px; }
  .body { padding:28px 32px; }
  .card { background:#f8fafc; border-radius:10px; padding:18px 20px; margin:16px 0; }
  .row { display:flex; justify-content:space-between; margin-bottom:8px; font-size:14px; }
  .row .label { color:#64748b; }
  .row .value { font-weight:600; color:#1e293b; }
  .badge { display:inline-block; padding:6px 14px; border-radius:20px; font-size:13px; font-weight:600; }
  .badge-blue { background:#dbeafe; color:#1d4ed8; }
  .badge-green { background:#dcfce7; color:#166534; }
  .badge-red { background:#fee2e2; color:#dc2626; }
  .footer { padding:20px 32px; text-align:center; font-size:12px; color:#94a3b8; border-top:1px solid #e2e8f0; }
  h2 { font-size:18px; color:#1e293b; margin:0 0 6px; }
  p { font-size:14px; color:#475569; line-height:1.6; margin:0 0 12px; }
  .note { background:#fffbeb; border:1px solid #fbbf24; border-radius:8px; padding:12px 16px; font-size:13px; color:#92400e; margin:16px 0; }
</style>
</head>
<body>
<div class="wrap">
  <div class="header">
    <h1>🏥 DoctorBook</h1>
    <p>${title}</p>
  </div>
  <div class="body">
    ${body}
  </div>
  <div class="footer">
    DoctorBook — Your Health, Our Priority<br>
    This is an automated message, please do not reply.
  </div>
</div>
</body>
</html>`;
}

// ─── OTP ─────────────────────────────────────────────────────────────────────

export async function sendOtpEmail(to: string, otp: string, name?: string) {
  const body = `
    <h2>Your verification code</h2>
    <p>Hello${name ? ` ${name}` : ''},</p>
    <p>Use the following OTP to verify your account. It expires in <strong>10 minutes</strong>.</p>
    <div style="text-align:center;margin:24px 0">
      <div style="display:inline-block;background:#2563EB;color:#fff;font-size:36px;font-weight:700;letter-spacing:8px;padding:16px 32px;border-radius:12px">${otp}</div>
    </div>
    <p>If you did not request this code, please ignore this email.</p>`;
  await send(to, 'Your DoctorBook OTP', base('Account Verification', body));
}

// ─── Booking Confirmation ─────────────────────────────────────────────────────

export async function sendBookingConfirmationEmail(opts: {
  to: string;
  patientName: string;
  doctorName: string;
  clinicName: string;
  date: string;
  startTime: string;
  endTime: string;
  bookingId: string;
}) {
  const body = `
    <h2>Appointment Confirmed ✅</h2>
    <p>Hello ${opts.patientName},</p>
    <p>Your appointment has been successfully booked. Here are your details:</p>
    <div class="card">
      <div class="row"><span class="label">Doctor</span><span class="value">Dr. ${opts.doctorName}</span></div>
      <div class="row"><span class="label">Clinic</span><span class="value">${opts.clinicName}</span></div>
      <div class="row"><span class="label">Date</span><span class="value">${opts.date}</span></div>
      <div class="row"><span class="label">Time</span><span class="value">${opts.startTime} – ${opts.endTime}</span></div>
      <div class="row"><span class="label">Booking ID</span><span class="value">${opts.bookingId}</span></div>
    </div>
    <div class="note">
      ⏰ <strong>Please note:</strong> The scheduled time is approximate. Actual consultation time may vary slightly depending on earlier appointments. Please arrive 5–10 minutes early.
    </div>
    <p>Please carry a valid ID and any previous medical records relevant to your visit.</p>`;
  await send(opts.to, `Appointment Confirmed — Dr. ${opts.doctorName}`, base('Booking Confirmation', body));
}

// ─── Appointment Reminder ─────────────────────────────────────────────────────

export async function sendAppointmentReminderEmail(opts: {
  to: string;
  patientName: string;
  doctorName: string;
  clinicName: string;
  clinicAddress: string;
  date: string;
  startTime: string;
  bookingId: string;
  hoursAhead: number;
}) {
  const body = `
    <h2>Appointment Reminder 🔔</h2>
    <p>Hello ${opts.patientName},</p>
    <p>This is a reminder that you have an appointment in <strong>${opts.hoursAhead} hour${opts.hoursAhead !== 1 ? 's' : ''}</strong>.</p>
    <div class="card">
      <div class="row"><span class="label">Doctor</span><span class="value">Dr. ${opts.doctorName}</span></div>
      <div class="row"><span class="label">Clinic</span><span class="value">${opts.clinicName}</span></div>
      <div class="row"><span class="label">Address</span><span class="value">${opts.clinicAddress}</span></div>
      <div class="row"><span class="label">Time</span><span class="value">${opts.startTime}</span></div>
      <div class="row"><span class="label">Booking ID</span><span class="value">${opts.bookingId}</span></div>
    </div>
    <div class="note">⏰ Times are approximate — please arrive 5–10 minutes early.</div>`;
  await send(opts.to, `Reminder: Appointment in ${opts.hoursAhead}h — Dr. ${opts.doctorName}`, base('Appointment Reminder', body));
}

// ─── Cancellation Sorry (from Doctor) ────────────────────────────────────────

export async function sendCancellationSorryEmail(opts: {
  to: string;
  patientName: string;
  doctorName: string;
  date: string;
  startTime: string;
  reason: string;
}) {
  const body = `
    <h2>Appointment Cancelled</h2>
    <p>Dear ${opts.patientName},</p>
    <p>We sincerely apologise for the inconvenience. Dr. ${opts.doctorName} has had to cancel your appointment scheduled for <strong>${opts.date} at ${opts.startTime}</strong>.</p>
    <div class="card">
      <div class="row"><span class="label">Reason</span><span class="value">${opts.reason}</span></div>
    </div>
    <p>We are sorry for the disruption to your plans. Please book a new appointment at your earliest convenience. We assure you of our best service.</p>
    <p>— Team DoctorBook</p>`;
  await send(opts.to, `Your appointment with Dr. ${opts.doctorName} has been cancelled`, base('Appointment Cancellation', body));
}

// ─── Doctor Verification ──────────────────────────────────────────────────────

export async function sendDoctorVerificationEmail(to: string, doctorName: string, status: 'VERIFIED' | 'REJECTED') {
  const approved = status === 'VERIFIED';
  const body = approved
    ? `<h2>Account Verified ✅</h2>
       <p>Dear Dr. ${doctorName},</p>
       <p>Congratulations! Your DoctorBook account has been <strong>verified</strong>. You can now log in and start accepting patient appointments.</p>
       <p>We look forward to having you on the platform and wish you great success.</p>`
    : `<h2>Verification Update</h2>
       <p>Dear Dr. ${doctorName},</p>
       <p>We regret to inform you that your account verification was not successful at this time. Please contact our support team with your credentials and documentation for further assistance.</p>`;
  await send(to, approved ? 'Your DoctorBook account is now verified' : 'DoctorBook — Verification update', base('Doctor Account', body));
}

// ─── Password Reset ───────────────────────────────────────────────────────────

export async function sendPasswordResetEmail(to: string, name: string, resetToken: string, baseUrl: string) {
  const resetUrl = `${baseUrl}/reset-password?token=${resetToken}`;
  const body = `
    <h2>Reset Your Password</h2>
    <p>Hello ${name},</p>
    <p>We received a request to reset your DoctorBook password. Click the button below within <strong>30 minutes</strong>:</p>
    <div style="text-align:center;margin:24px 0">
      <a href="${resetUrl}" style="display:inline-block;background:#2563EB;color:#fff;text-decoration:none;padding:14px 28px;border-radius:8px;font-weight:600;font-size:15px">Reset Password</a>
    </div>
    <p style="font-size:12px;color:#94a3b8">If you did not request this, you can safely ignore this email.</p>`;
  await send(to, 'Reset your DoctorBook password', base('Password Reset', body));
}
