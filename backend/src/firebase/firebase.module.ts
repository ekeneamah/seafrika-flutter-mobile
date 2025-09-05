import { Module, Global } from '@nestjs/common';
import { FirebaseAdminService } from './firebase-admin.service';
import { FirebaseAuthService } from './firebase-auth.service';
import { FirebaseStorageService } from './firebase-storage.service';
import { FirebaseMessagingService } from './firebase-messaging.service';
import { FirestoreService } from './firestore.service';
import { FirebaseController } from './firebase.controller';

@Global()
@Module({
  controllers: [FirebaseController],
  providers: [
    FirebaseAdminService,
    FirebaseAuthService,
    FirebaseStorageService,
    FirebaseMessagingService,
    FirestoreService,
  ],
  exports: [
    FirebaseAdminService,
    FirebaseAuthService,
    FirebaseStorageService,
    FirebaseMessagingService,
    FirestoreService,
  ],
})
export class FirebaseModule {}
