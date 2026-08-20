import { PasswordService } from '../src/auth/password.service';

describe('PasswordService', () => {
  const service = new PasswordService();

  it('hashes and verifies passwords without storing the raw password', async () => {
    const hash = await service.hash('merchant-secret');

    expect(hash).not.toBe('merchant-secret');
    await expect(service.verify('merchant-secret', hash)).resolves.toBe(true);
    await expect(service.verify('wrong-password', hash)).resolves.toBe(false);
  });
});
