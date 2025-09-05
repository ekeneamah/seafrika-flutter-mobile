import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { ProductsModule } from './products/products.module';
import { FirebaseModule } from './firebase/firebase.module';
import { FirestoreModule } from './firestore/firestore.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import configuration from './config/configuration';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
      load: [configuration],
    }),
    FirebaseModule,
    FirestoreModule,
    AuthModule,
    ProductsModule,
    WebhooksModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
