import { 
  Controller, 
  Post, 
  Body, 
  HttpCode, 
  HttpStatus, 
  UseGuards,
  Request,
  Get,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
// import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
// import { LocalAuthGuard } from './guards/local-auth.guard';
// import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  // constructor(private authService: AuthService) {}

  @Post('register')
  @ApiOperation({ summary: 'Register a new user' })
  @ApiResponse({ status: 201, description: 'User registered successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  async register(@Body() registerDto: RegisterDto) {
    // return this.authService.register(registerDto);
    return { message: 'Register endpoint - not yet implemented' };
  }

  // @UseGuards(LocalAuthGuard)
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login user' })
  @ApiResponse({ status: 200, description: 'User logged in successfully' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async login(@Body() loginDto: LoginDto, @Request() req: any) {
    // return this.authService.login(req.user);
    return { message: 'Login endpoint - not yet implemented' };
  }

  // @UseGuards(JwtAuthGuard)
  @Get('profile')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get user profile' })
  @ApiResponse({ status: 200, description: 'User profile retrieved' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  getProfile(@Request() req: any) {
    // return req.user;
    return { message: 'Profile endpoint - not yet implemented' };
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  @ApiResponse({ status: 200, description: 'Token refreshed successfully' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async refresh(@Body('refreshToken') refreshToken: string) {
    // return this.authService.refreshToken(refreshToken);
    return { message: 'Refresh endpoint - not yet implemented' };
  }
}
