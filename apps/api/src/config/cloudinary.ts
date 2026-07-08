import { v2 as cloudinary } from 'cloudinary';
import { env } from './env';
import { logger } from '../common/utils/logger';

export function initializeCloudinary(): void {
  if (!env.CLOUDINARY_CLOUD_NAME) {
    logger.warn('Cloudinary not configured — file uploads disabled');
    return;
  }

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true,
  });

  logger.info('Cloudinary initialized');
}

export async function uploadImage(
  filePath: string,
  folder: string,
  publicId?: string,
): Promise<string> {
  const result = await cloudinary.uploader.upload(filePath, {
    folder: `doctor-booking/${folder}`,
    public_id: publicId,
    overwrite: true,
    resource_type: 'image',
    transformation: [{ quality: 'auto', fetch_format: 'auto' }],
  });
  return result.secure_url;
}

export async function deleteImage(publicId: string): Promise<void> {
  await cloudinary.uploader.destroy(publicId);
}

export { cloudinary };
