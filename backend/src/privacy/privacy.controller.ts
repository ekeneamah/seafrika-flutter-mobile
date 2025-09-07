import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';

@Controller('privacy')
export class PrivacyController {
  @Get('policy')
  getPrivacyPolicy(@Res() res: Response) {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - SeAfrika</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f9f9f9;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        .update-date {
            color: #7f8c8d;
            font-style: italic;
            margin-bottom: 30px;
        }
        .contact-info {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        ul {
            padding-left: 20px;
        }
        li {
            margin-bottom: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Privacy Policy</h1>
        <p class="update-date">Last updated: September 7, 2025</p>

        <h2>1. Introduction</h2>
        <p>Welcome to SeAfrika ("we", "our", or "us"). We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.</p>

        <h2>2. Information We Collect</h2>
        
        <h3>2.1 Personal Information</h3>
        <p>We may collect the following types of personal information:</p>
        <ul>
            <li>Name and contact information (email address, phone number)</li>
            <li>Business information and profile details</li>
            <li>Account credentials and authentication data</li>
            <li>Payment and billing information</li>
        </ul>

        <h3>2.2 Social Media Integration</h3>
        <p>When you connect your Instagram Business account:</p>
        <ul>
            <li>Instagram Business account information (username, follower count, media)</li>
            <li>Facebook Page information (if connected to Instagram Business account)</li>
            <li>Content and analytics data from your connected accounts</li>
            <li>Access tokens for API integration (stored securely)</li>
        </ul>

        <h3>2.3 Usage Data</h3>
        <p>We automatically collect certain information when you use our app:</p>
        <ul>
            <li>Device information (type, operating system, unique identifiers)</li>
            <li>App usage analytics and performance data</li>
            <li>Log data and error reports</li>
            <li>Location data (if enabled by you)</li>
        </ul>

        <h2>3. How We Use Your Information</h2>
        <p>We use the collected information for the following purposes:</p>
        <ul>
            <li>Provide and maintain our services</li>
            <li>Process transactions and manage your account</li>
            <li>Integrate with social media platforms (Instagram, Facebook)</li>
            <li>Analyze and improve our app performance</li>
            <li>Send important updates and notifications</li>
            <li>Provide customer support</li>
            <li>Comply with legal obligations</li>
        </ul>

        <h2>4. Information Sharing</h2>
        <p>We do not sell, trade, or rent your personal information to third parties. We may share your information in the following circumstances:</p>
        <ul>
            <li><strong>Service Providers:</strong> With trusted third-party services that help us operate our app (Firebase, Google Cloud, payment processors)</li>
            <li><strong>Social Media Platforms:</strong> With Instagram and Facebook for integration purposes, following their respective privacy policies</li>
            <li><strong>Legal Requirements:</strong> When required by law or to protect our rights and safety</li>
            <li><strong>Business Transfers:</strong> In connection with any merger, sale, or acquisition of our company</li>
        </ul>

        <h2>5. Data Security</h2>
        <p>We implement appropriate technical and organizational measures to protect your personal information:</p>
        <ul>
            <li>Encryption of data in transit and at rest</li>
            <li>Secure API token management</li>
            <li>Regular security audits and updates</li>
            <li>Access controls and authentication</li>
            <li>Firebase security rules and Cloud Functions protection</li>
        </ul>

        <h2>6. Third-Party Services</h2>
        <p>Our app integrates with third-party services that have their own privacy policies:</p>
        <ul>
            <li><strong>Google Firebase:</strong> <a href="https://firebase.google.com/support/privacy">Firebase Privacy Policy</a></li>
            <li><strong>Instagram/Facebook:</strong> <a href="https://www.facebook.com/privacy/policy">Meta Privacy Policy</a></li>
            <li><strong>Google Cloud Platform:</strong> <a href="https://cloud.google.com/privacy">Google Cloud Privacy Policy</a></li>
        </ul>

        <h2>7. Your Rights and Choices</h2>
        <p>You have the following rights regarding your personal information:</p>
        <ul>
            <li><strong>Access:</strong> Request access to your personal data</li>
            <li><strong>Correction:</strong> Request correction of inaccurate information</li>
            <li><strong>Deletion:</strong> Request deletion of your personal data</li>
            <li><strong>Portability:</strong> Request a copy of your data in a portable format</li>
            <li><strong>Withdraw Consent:</strong> Disconnect social media integrations at any time</li>
            <li><strong>Opt-out:</strong> Unsubscribe from marketing communications</li>
        </ul>

        <h2>8. Data Retention</h2>
        <p>We retain your information for as long as necessary to provide our services and comply with legal obligations:</p>
        <ul>
            <li>Account information: Until account deletion</li>
            <li>Social media tokens: Until disconnection or expiry</li>
            <li>Analytics data: Up to 2 years</li>
            <li>Support communications: Up to 3 years</li>
        </ul>

        <h2>9. Children's Privacy</h2>
        <p>Our services are not directed to children under 13 years of age. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us.</p>

        <h2>10. International Data Transfers</h2>
        <p>Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place for such transfers in compliance with applicable data protection laws.</p>

        <h2>11. Changes to This Privacy Policy</h2>
        <p>We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically for any changes.</p>

        <h2>12. Contact Information</h2>
        <div class="contact-info">
            <p><strong>SeAfrika Privacy Team</strong></p>
            <p>Email: privacy@seafrika.com</p>
            <p>Address: [Your Business Address]</p>
            <p>Phone: [Your Contact Number]</p>
        </div>

        <p>If you have any questions about this Privacy Policy or our privacy practices, please contact us using the information provided above.</p>

        <hr style="margin: 40px 0; border: none; border-top: 1px solid #ecf0f1;">
        <p style="text-align: center; color: #7f8c8d; font-size: 14px;">
            © 2025 SeAfrika. All rights reserved.
        </p>
    </div>
</body>
</html>
    `;

    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  }

  @Get('terms')
  getTermsOfService(@Res() res: Response) {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Service - SeAfrika</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f9f9f9;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        .update-date {
            color: #7f8c8d;
            font-style: italic;
            margin-bottom: 30px;
        }
        .contact-info {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        ul {
            padding-left: 20px;
        }
        li {
            margin-bottom: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Terms of Service</h1>
        <p class="update-date">Last updated: September 7, 2025</p>

        <h2>1. Acceptance of Terms</h2>
        <p>By accessing and using the SeAfrika mobile application ("App"), you accept and agree to be bound by the terms and provision of this agreement.</p>

        <h2>2. Description of Service</h2>
        <p>SeAfrika provides a platform for business management and social media integration, specifically designed for Instagram Business accounts and related services.</p>

        <h2>3. User Accounts</h2>
        <p>You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.</p>

        <h2>4. Privacy Policy</h2>
        <p>Your privacy is important to us. Please review our Privacy Policy, which also governs your use of the Service, to understand our practices.</p>

        <h2>5. Prohibited Uses</h2>
        <p>You may not use our service for any illegal or unauthorized purpose or to violate any laws in your jurisdiction.</p>

        <h2>6. Intellectual Property</h2>
        <p>The service and its original content, features, and functionality are and will remain the exclusive property of SeAfrika and its licensors.</p>

        <h2>7. Termination</h2>
        <p>We may terminate or suspend your account and bar access to the service immediately, without prior notice or liability, under our sole discretion, for any reason whatsoever.</p>

        <h2>8. Limitation of Liability</h2>
        <p>In no event shall SeAfrika, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages.</p>

        <h2>9. Contact Information</h2>
        <div class="contact-info">
            <p><strong>SeAfrika Legal Team</strong></p>
            <p>Email: legal@seafrika.com</p>
            <p>Address: [Your Business Address]</p>
        </div>

        <hr style="margin: 40px 0; border: none; border-top: 1px solid #ecf0f1;">
        <p style="text-align: center; color: #7f8c8d; font-size: 14px;">
            © 2025 SeAfrika. All rights reserved.
        </p>
    </div>
</body>
</html>
    `;

    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  }
}
