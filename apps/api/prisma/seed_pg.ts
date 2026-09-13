import { Client } from 'pg';
import bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';

const client = new Client({
  connectionString: 'postgresql://doctorapp:postgres123@localhost:5432/doctor_booking'
});

async function main() {
  await client.connect();
  console.log('🌱 Seeding database...');

  // Super Admin
  const adminHash = await bcrypt.hash('Admin@123456', 12);
  const adminId = randomUUID();
  await client.query(`
    INSERT INTO admins (id, email, "passwordHash", name, role, "createdAt", "updatedAt")
    VALUES ($1, $2, $3, $4, 'SUPER_ADMIN', NOW(), NOW())
    ON CONFLICT (email) DO NOTHING
  `, [adminId, 'admin@doctorbooking.com', adminHash, 'Super Admin']);
  console.log('✅ Admin created: admin@doctorbooking.com');

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
    const catId = randomUUID();
    await client.query(`
      INSERT INTO categories (id, name, slug, color, "sortOrder", "createdAt", "updatedAt")
      VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    `, [catId, cat.name, cat.slug, cat.color, cat.sortOrder]);
  }
  console.log('✅ 10 categories created');

  // Sample Clinic
  const clinicId = 'seed-clinic-1';
  await client.query(`
    INSERT INTO clinics (id, name, "addressLine1", city, state, country, lat, lng, phone, email, "parkingAvailable", images, "createdAt", "updatedAt")
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING
  `, [
    clinicId, 'City Medical Centre', '123 MG Road', 'Bangalore', 'Karnataka', 'India',
    12.9716, 77.5946, '+91-9876543210', 'info@citymedical.com', true,
    '{"https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=800","https://images.unsplash.com/photo-1516549655169-df83a0774514?w=800","https://images.unsplash.com/photo-1581056771107-24ca5f033842?w=800"}'
  ]);
  console.log('✅ Sample clinic created');

  // Sample Doctor
  const doctorHash = await bcrypt.hash('Doctor@123456', 12);
  const doctorId = randomUUID();
  await client.query(`
    INSERT INTO doctors (id, email, "passwordHash", name, phone, gender, about, qualifications, "experienceYears", languages, "verificationStatus", "verifiedAt", "isActive", "averageRating", "totalReviews", "createdAt", "updatedAt")
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), true, 4.8, 127, NOW(), NOW())
    ON CONFLICT (email) DO UPDATE SET id = doctors.id RETURNING id
  `, [
    doctorId,
    'dr.sharma@doctorbooking.com',
    doctorHash,
    'Dr. Rajesh Sharma',
    '+91-9876543211',
    'MALE',
    'Experienced cardiologist with 15 years of practice. Specialises in interventional cardiology, heart failure management, and preventive cardiology.',
    '{"MBBS","MD (Cardiology)","FACC"}',
    15,
    '{"English","Hindi","Kannada"}',
    'VERIFIED'
  ]);

  // Get actual doctor id
  const docRow = await client.query(`SELECT id FROM doctors WHERE email = 'dr.sharma@doctorbooking.com'`);
  const actualDoctorId = docRow.rows[0].id;

  // Assign Cardiology category
  const catRow = await client.query(`SELECT id FROM categories WHERE slug = 'cardiology'`);
  if (catRow.rows.length > 0) {
    await client.query(`
      INSERT INTO doctor_categories (id, "doctorId", "categoryId", "isPrimary", "createdAt")
      VALUES ($1, $2, $3, true, NOW())
      ON CONFLICT ("doctorId", "categoryId") DO NOTHING
    `, [randomUUID(), actualDoctorId, catRow.rows[0].id]);
  }

  // Assign General Physician category too
  const gpRow = await client.query(`SELECT id FROM categories WHERE slug = 'general-physician'`);
  if (gpRow.rows.length > 0) {
    await client.query(`
      INSERT INTO doctor_categories (id, "doctorId", "categoryId", "isPrimary", "createdAt")
      VALUES ($1, $2, $3, false, NOW())
      ON CONFLICT ("doctorId", "categoryId") DO NOTHING
    `, [randomUUID(), actualDoctorId, gpRow.rows[0].id]);
  }

  // Link doctor to clinic
  const dcId = randomUUID();
  await client.query(`
    INSERT INTO doctor_clinics (id, "doctorId", "clinicId", "consultationFee", "isPrimary", "isActive", "createdAt", "updatedAt")
    VALUES ($1, $2, $3, 800, true, true, NOW(), NOW())
    ON CONFLICT ("doctorId", "clinicId") DO UPDATE SET id = doctor_clinics.id RETURNING id
  `, [dcId, actualDoctorId, clinicId]);
  const dcRow = await client.query(`SELECT id FROM doctor_clinics WHERE "doctorId" = $1 AND "clinicId" = $2`, [actualDoctorId, clinicId]);
  const actualDcId = dcRow.rows[0].id;

  // Set availability Mon-Fri 9am-5pm
  const workdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];
  for (const day of workdays) {
    await client.query(`
      INSERT INTO doctor_availabilities (id, "doctorId", "doctorClinicId", "dayOfWeek", "startTime", "endTime", "slotDurationMinutes", "breakStart", "breakEnd", "isActive", "createdAt", "updatedAt")
      VALUES ($1, $2, $3, $4, '09:00', '17:00', 15, '13:00', '14:00', true, NOW(), NOW())
      ON CONFLICT ("doctorId", "doctorClinicId", "dayOfWeek") DO NOTHING
    `, [randomUUID(), actualDoctorId, actualDcId, day as any]);
  }

  // Second doctor
  const doctor2Hash = await bcrypt.hash('Doctor@123456', 12);
  const doctor2Id = randomUUID();
  await client.query(`
    INSERT INTO doctors (id, email, "passwordHash", name, phone, gender, about, qualifications, "experienceYears", languages, "verificationStatus", "verifiedAt", "isActive", "averageRating", "totalReviews", "createdAt", "updatedAt")
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), true, 4.6, 89, NOW(), NOW())
    ON CONFLICT (email) DO NOTHING
  `, [
    doctor2Id,
    'dr.priya@doctorbooking.com',
    doctor2Hash,
    'Dr. Priya Nair',
    '+91-9876543212',
    'FEMALE',
    'Specialist in dermatology and cosmetology with expertise in skin conditions, hair disorders, and aesthetic treatments.',
    '{"MBBS","MD (Dermatology)","Fellowship in Cosmetology"}',
    8,
    '{"English","Hindi","Malayalam","Tamil"}',
    'VERIFIED'
  ]);

  const doc2Row = await client.query(`SELECT id FROM doctors WHERE email = 'dr.priya@doctorbooking.com'`);
  if (doc2Row.rows.length > 0) {
    const actualDoctor2Id = doc2Row.rows[0].id;
    const dermRow = await client.query(`SELECT id FROM categories WHERE slug = 'dermatology'`);
    if (dermRow.rows.length > 0) {
      await client.query(`
        INSERT INTO doctor_categories (id, "doctorId", "categoryId", "isPrimary", "createdAt")
        VALUES ($1, $2, $3, true, NOW())
        ON CONFLICT ("doctorId", "categoryId") DO NOTHING
      `, [randomUUID(), actualDoctor2Id, dermRow.rows[0].id]);
    }
    const dc2Id = randomUUID();
    await client.query(`
      INSERT INTO doctor_clinics (id, "doctorId", "clinicId", "consultationFee", "isPrimary", "isActive", "createdAt", "updatedAt")
      VALUES ($1, $2, $3, 600, true, true, NOW(), NOW())
      ON CONFLICT ("doctorId", "clinicId") DO NOTHING RETURNING id
    `, [dc2Id, actualDoctor2Id, clinicId]);
    const dc2Row = await client.query(`SELECT id FROM doctor_clinics WHERE "doctorId" = $1 AND "clinicId" = $2`, [actualDoctor2Id, clinicId]);
    if (dc2Row.rows.length > 0) {
      const actualDc2Id = dc2Row.rows[0].id;
      const allDays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
      for (const day of allDays) {
        await client.query(`
          INSERT INTO doctor_availabilities (id, "doctorId", "doctorClinicId", "dayOfWeek", "startTime", "endTime", "slotDurationMinutes", "isActive", "createdAt", "updatedAt")
          VALUES ($1, $2, $3, $4, '10:00', '18:00', 20, true, NOW(), NOW())
          ON CONFLICT ("doctorId", "doctorClinicId", "dayOfWeek") DO NOTHING
        `, [randomUUID(), actualDoctor2Id, actualDc2Id, day as any]);
      }
    }
  }

  // App settings
  await client.query(`
    INSERT INTO app_settings (id, key, value, type, "updatedAt")
    VALUES ($1, $2, $3, $4, NOW())
    ON CONFLICT (key) DO NOTHING
  `, [randomUUID(), 'otp_expiry_minutes', '10', 'number']);

  console.log('✅ 2 doctors created');
  console.log('\n🎉 Seeding complete!');
  console.log('\n📋 Credentials:');
  console.log('  Admin:   admin@doctorbooking.com / Admin@123456');
  console.log('  Doctor:  dr.sharma@doctorbooking.com / Doctor@123456');
  console.log('  Doctor2: dr.priya@doctorbooking.com / Doctor@123456');

  await client.end();
}

main().catch(e => { console.error(e); process.exit(1); });
