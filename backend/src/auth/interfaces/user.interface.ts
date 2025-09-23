export interface User {
  id: string;
  businessId?: string;
  vendorId: string;
  email: string;
  firstName: string;
  lastName: string;
  businessName?: string;
  businessAddress?: string;
  country?: string;
  state?: string;
  phone?: string;
  profileImage?: string;
  teamIds: string[];
  roles: string[];
  isActive: boolean;
  createdAt: Date;
  lastLoginAt?: Date;
  permissions: string[];
  storeRoles: { [key: string]: string[] };
  defaultPasswordChanged: boolean;
  dateOfBirth?: Date;
  weddingAnniversary?: Date;
  address?: string;
  hobbies?: string;
  notes?: string;
  accessToken?: string; // Added for integrations
}