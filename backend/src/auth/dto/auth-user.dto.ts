import { User } from '../interfaces/user.interface';

export class AuthUserDto implements Partial<User> {
  id!: string;
  email!: string;
  firstName!: string;
  lastName!: string;
  accessToken?: string;
  businessId?: string;
  businessName?: string;
}