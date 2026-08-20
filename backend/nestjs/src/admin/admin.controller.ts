import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { AdminService } from './admin.service';
import {
  AdjustCustomerPointsDto,
  AdminListCashRequestsDto,
  CreateBannerDto,
  CreateDigitalProductDto,
  CreateGovernorateDto,
  CreateMerchantAccountDto,
  CreateStoreDto,
  ResolveCashRequestDto,
  SettleStoreDto,
  SettlementQueryDto,
  UpdateBannerDto,
  UpdateDigitalProductDto,
  UpdateGovernorateDto,
  UpdatePointSettingsDto,
  UpdateStoreDto,
} from './dto/admin.dto';

@Roles(UserRole.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('overview')
  overview() {
    return this.admin.overview();
  }

  @Get('customers')
  listCustomers() {
    return this.admin.listCustomers();
  }

  @Post('customers/:customerId/points/grant')
  grantPoints(
    @CurrentUser() user: AuthenticatedUser,
    @Param('customerId') customerId: string,
    @Body() dto: AdjustCustomerPointsDto,
  ) {
    return this.admin.grantPoints(user.id, customerId, dto);
  }

  @Post('customers/:customerId/points/deduct')
  deductPoints(
    @CurrentUser() user: AuthenticatedUser,
    @Param('customerId') customerId: string,
    @Body() dto: AdjustCustomerPointsDto,
  ) {
    return this.admin.deductPoints(user.id, customerId, dto);
  }

  @Delete('customers/:customerId')
  deleteCustomer(@Param('customerId') customerId: string) {
    return this.admin.deleteCustomer(customerId);
  }

  @Get('cash-requests')
  listCashRequests(@Query() query: AdminListCashRequestsDto) {
    return this.admin.listCashRequests(query);
  }

  @Post('cash-requests/:requestId/resolve')
  resolveCashRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Param('requestId') requestId: string,
    @Body() dto: ResolveCashRequestDto,
  ) {
    return this.admin.resolveCashRequest(user.id, requestId, dto.approve);
  }

  @Get('stores')
  listStores() {
    return this.admin.listStores();
  }

  @Get('governorates')
  listGovernorates() {
    return this.admin.listGovernorates();
  }

  @Get('banners')
  listBanners(@Query('placement') placement?: string) {
    return this.admin.listBanners(placement);
  }

  @Post('banners')
  createBanner(@Body() dto: CreateBannerDto) {
    return this.admin.createBanner(dto);
  }

  @Patch('banners/:bannerId')
  updateBanner(@Param('bannerId') bannerId: string, @Body() dto: UpdateBannerDto) {
    return this.admin.updateBanner(bannerId, dto);
  }

  @Post('governorates')
  createGovernorate(@Body() dto: CreateGovernorateDto) {
    return this.admin.createGovernorate(dto);
  }

  @Patch('governorates/:governorateId')
  updateGovernorate(
    @Param('governorateId') governorateId: string,
    @Body() dto: UpdateGovernorateDto,
  ) {
    return this.admin.updateGovernorate(governorateId, dto);
  }

  @Post('stores')
  createStore(@Body() dto: CreateStoreDto) {
    return this.admin.createStore(dto);
  }

  @Patch('stores/:storeId')
  updateStore(@Param('storeId') storeId: string, @Body() dto: UpdateStoreDto) {
    return this.admin.updateStore(storeId, dto);
  }

  @Get('products')
  listProducts() {
    return this.admin.listProducts();
  }

  @Post('products')
  createProduct(@Body() dto: CreateDigitalProductDto) {
    return this.admin.createProduct(dto);
  }

  @Patch('products/:productId')
  updateProduct(@Param('productId') productId: string, @Body() dto: UpdateDigitalProductDto) {
    return this.admin.updateProduct(productId, dto);
  }

  @Get('merchant-accounts')
  listMerchantAccounts() {
    return this.admin.listMerchantAccounts();
  }

  @Post('merchant-accounts')
  createMerchantAccount(@Body() dto: CreateMerchantAccountDto) {
    return this.admin.createMerchantAccount(dto);
  }

  @Get('settings')
  getSettings() {
    return this.admin.getSettings();
  }

  @Patch('settings')
  updateSettings(@Body() dto: UpdatePointSettingsDto) {
    return this.admin.updateSettings(dto);
  }

  @Get('settlements')
  listSettlements(@Query() query: SettlementQueryDto) {
    return this.admin.listSettlements(query);
  }

  @Post('settlements/settle')
  settleStore(@CurrentUser() user: AuthenticatedUser, @Body() dto: SettleStoreDto) {
    return this.admin.settleStore(user.id, dto);
  }
}
