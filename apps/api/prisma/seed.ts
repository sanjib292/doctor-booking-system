import { PrismaClient, VerificationStatus, DayOfWeek } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Super admin
  const adminHash = await bcrypt.hash('Admin@123456', 12);
  const admin = await prisma.admin.upsert({
    where: { email: 'admin@doctorbooking.com' },
    update: {},
    create: {
      email: 'admin@doctorbooking.com',
      passwordHash: adminHash,
      name: 'Super Admin',
      role: 'SUPER_ADMIN',
    },
  });
  console.log('✅ Admin created:', admin.email);

  // Categories
  const categories = [
    { name: 'General Physician', slug: 'general-physician', color: '#4CAF50', sortOrder: 1 },
    { name: 'Cardiology', slug: 'cardiology', color: '#F44336', sortOrder: 2 },
    { name: 'Dermatology', slug: 'dermatology', color: '#FF9800', sortOrder: 3 },
    { name: 'Neurology', slug: 'neurology', color: '#9C27B0', sortOrder: 4 },
    { name: 'Orthopedics', slug: 'orthopedics', color: '#2196F3', sortOrder: 5 },
    { name: 'Pediatrics', slug: 'pediatrics', color: '#00BCD4', sortOrder: 6 },
    { name: 'Gynecology', slug: 'gynecology', color: '#E91E63', sortOrder: 7 },
    { name: 'ENT', slug: 'ent', color: '#795548', sortOrder: 8 },
    { name: 'Ophthalmology', slug: 'ophthalmology', color: '#607D8B', sortOrder: 9 },
    { name: 'Psychiatry', slug: 'psychiatry', color: '#3F51B5', sortOrder: 10 },
  ];

  for (const cat of categories) {
    await prisma.category.upsert({
      where: { slug: cat.slug },
      update: {},
      create: cat,
    });
  }
  console.log(`✅ ${categories.length} categories created`);

  // Sample clinic
  const clinic = await prisma.clinic.upsert({
    where: { id: 'seed-clinic-1' },
    update: {},
    create: {
      id: 'seed-clinic-1',
      name: 'City Medical Centre',
      addressLine1: '123 MG Road',
      city: 'Bangalore',
      state: 'Karnataka',
      lat: 12.9716,
      lng: 77.5946,
      phone: '+91-9876543210',
      email: 'info@citymedical.com',
      parkingAvailable: true,
    },
  });
  console.log('✅ Sample clinic created');

  // Sample doctor
  const doctorHash = await bcrypt.hash('Doctor@123456', 12);
  const doctor = await prisma.doctor.upsert({
    where: { email: 'dr.sharma@doctorbooking.com' },
    update: {},
    create: {
      email: 'dr.sharma@doctorbooking.com',
      passwordHash: doctorHash,
      name: 'Dr. Rajesh Sharma',
      phone: '+91-9876543211',
      gender: 'MALE',
      about: 'Experienced cardiologist with 15 years of practice.',
      qualifications: ['MBBS', 'MD (Cardiology)', 'FACC'],
      experienceYears: 15,
      languages: ['English', 'Hindi', 'Kannada'],
      verificationStatus: VerificationStatus.VERIFIED,
      verifiedAt: new Date(),
    },
  });

  // Assign category to doctor
  const cardiology = await prisma.category.findUnique({ where: { slug: 'cardiology' } });
  if (cardiology) {
    await prisma.doctorCategory.upsert({
      where: { doctorId_categoryId: { doctorId: doctor.id, categoryId: cardiology.id } },
      update: {},
      create: { doctorId: doctor.id, categoryId: cardiology.id, isPrimary: true },
    });
  }

  // Link doctor to clinic
  const doctorClinic = await prisma.doctorClinic.upsert({
    where: { doctorId_clinicId: { doctorId: doctor.id, clinicId: clinic.id } },
    update: {},
    create: {
      doctorId: doctor.id,
      clinicId: clinic.id,
      consultationFee: 800,
      isPrimary: true,
    },
  });

  // Set availability (Mon-Fri, 9am-5pm)
  const workdays: DayOfWeek[] = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];
  for (const day of workdays) {
    await prisma.doctorAvailability.upsert({
      where: {
        doctorId_doctorClinicId_dayOfWeek: {
          doctorId: doctor.id,
          doctorClinicId: doctorClinic.id,
          dayOfWeek: day,
        },
      },
      update: {},
      create: {
        doctorId: doctor.id,
        doctorClinicId: doctorClinic.id,
        dayOfWeek: day,
        startTime: '09:00',
        endTime: '17:00',
        slotDurationMinutes: 15,
        breakStart: '13:00',
        breakEnd: '14:00',
      },
    });
  }

  console.log('✅ Sample doctor created:', doctor.email);
  console.log('\n🎉 Seeding complete!');
  console.log('\nCredentials:');
  console.log('  Admin:  admin@doctorbooking.com / Admin@123456');
  console.log('  Doctor: dr.sharma@doctorbooking.com / Doctor@123456');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
