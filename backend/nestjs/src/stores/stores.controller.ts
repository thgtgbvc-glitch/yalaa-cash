import { Controller, Get, Query } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';
import { ListStoresDto } from './dto/list-stores.dto';
import { StoresService } from './stores.service';

@Controller('stores')
export class StoresController {
  constructor(private readonly stores: StoresService) {}

  @Public()
  @Get()
  list(@Query() query: ListStoresDto) {
    return this.stores.listActiveStores(query);
  }
}
