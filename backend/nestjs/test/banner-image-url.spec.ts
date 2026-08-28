import { validate } from "class-validator";
import { plainToInstance } from "class-transformer";
import { CreateBannerDto, UpdateBannerDto } from "../src/admin/dto/admin.dto";

/**
 * Covers backend-side structural validation of Banner.imageUrl
 * (@IsUrl on CreateBannerDto/UpdateBannerDto): scheme must be http/https and
 * host must be non-empty, but a file extension must NEVER be required —
 * matching the Admin Flutter validation exactly so the two layers never
 * disagree about what's a valid image URL.
 */

async function imageUrlErrors(imageUrl: string): Promise<boolean> {
  const dto = plainToInstance(CreateBannerDto, {
    title: "Test banner",
    imageUrl,
    displayOrder: 1,
  });
  const errors = await validate(dto);
  return errors.some((e) => e.property === "imageUrl");
}

describe("CreateBannerDto.imageUrl validation", () => {
  it.each([
    "https://example.com/image.jpg",
    "https://example.com/image.png",
    "https://cdn.example.com/assets/banner.webp",
    "https://example.com/image?id=123",
    "https://images.example.com/banner?width=1200&height=500",
  ])("accepts a valid image URL: %s", async (url) => {
    expect(await imageUrlErrors(url)).toBe(false);
  });

  it("accepts a valid https URL with no file extension at all", async () => {
    expect(await imageUrlErrors("https://images.example.com/banner")).toBe(false);
  });

  it("rejects a malformed URL", async () => {
    expect(await imageUrlErrors("not a url")).toBe(true);
  });

  it("rejects a non-http/https scheme (ftp)", async () => {
    expect(await imageUrlErrors("ftp://example.com/image.jpg")).toBe(true);
  });

  it("rejects an internal-looking path (no scheme/host)", async () => {
    expect(await imageUrlErrors("/stores?category=restaurants")).toBe(true);
  });

  it("rejects an empty string", async () => {
    expect(await imageUrlErrors("")).toBe(true);
  });
});

describe("UpdateBannerDto.imageUrl validation", () => {
  it("allows imageUrl to be omitted entirely (optional on update)", async () => {
    const dto = plainToInstance(UpdateBannerDto, { title: "Test" });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === "imageUrl")).toBe(false);
  });

  it("still rejects a malformed imageUrl when one IS provided", async () => {
    const dto = plainToInstance(UpdateBannerDto, { imageUrl: "not a url" });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === "imageUrl")).toBe(true);
  });

  it("accepts a valid https URL with query parameters", async () => {
    const dto = plainToInstance(UpdateBannerDto, {
      imageUrl: "https://images.example.com/banner?width=1200&height=500",
    });
    const errors = await validate(dto);
    expect(errors.some((e) => e.property === "imageUrl")).toBe(false);
  });
});
