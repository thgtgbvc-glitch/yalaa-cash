import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { presentStore } from "../common/presenters";
import { ListStoresDto } from "./dto/list-stores.dto";

@Injectable()
export class StoresService {
  constructor(private readonly prisma: PrismaService) {}

  async listActiveStores(query: ListStoresDto) {
    const stores = await this.prisma.store.findMany({
      where: {
        isActive: true,
        ...(query.city
          ? { city: { equals: query.city.trim(), mode: "insensitive" } }
          : {}),
        ...(query.category
          ? { category: { equals: query.category.trim(), mode: "insensitive" } }
          : {}),
      },
      orderBy: [{ city: "asc" }, { category: "asc" }, { name: "asc" }],
    });
    return { items: stores.map(presentStore) };
  }
}
