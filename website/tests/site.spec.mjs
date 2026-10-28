import {test, expect} from '@playwright/test';

for (const width of [320, 390, 768, 1440]) {
  test(`Home and policy pages fit ${width}px`, async ({page})=>{
    await page.setViewportSize({width,height:900});
    const errors = [];
    page.on('pageerror',error=>errors.push(error.message));
    page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
    for (const route of ['/', '/privacy','/terms','/support']) {
      const response = await page.goto(route);
      expect(response.status()).toBe(200);
      await expect(page.locator('h1')).toBeVisible();
      expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
      await expect(page.locator('.site-footer a[href="/privacy"]')).toHaveCount(1);
    }
    expect(errors).toEqual([]);
  });
}

test('Demo, mobile navigation and legal links are functional without requesting camera or location',async({page,context})=>{
  await page.setViewportSize({width:390,height:844});
  const external = [];
  page.on('request',request=>{if(!request.url().startsWith('http://127.0.0.1:4183'))external.push(request.url());});
  await page.goto('/');
  const logo = page.getByRole('button',{name:'Logo',exact:true});
  await logo.click();
  await expect(logo).toHaveAttribute('aria-pressed','false');
  await expect(page.locator('[data-demo="logo"]')).toBeHidden();
  await logo.click();
  await expect(page.locator('[data-demo="logo"]')).toBeVisible();
  await page.getByRole('button',{name:'Lokasi',exact:true}).click();
  await expect(page.locator('[data-demo="location"]')).toBeHidden();
  await page.getByRole('button',{name:'Simulasikan jepretan pada ilustrasi'}).click();
  await expect(page.getByRole('status')).toContainText('Tidak ada foto');
  const menu = page.getByRole('button',{name:'Buka menu navigasi'});
  await menu.click();
  await expect(menu).toHaveAttribute('aria-expanded','true');
  await page.getByRole('navigation',{name:'Navigasi utama'}).getByRole('link',{name:'Privasi'}).click();
  await expect(page).toHaveURL(/\/privacy$/);
  await page.getByRole('navigation',{name:'Daftar isi halaman'}).getByRole('link',{name:'7. Menghentikan sync dan menghapus data'}).click();
  await expect(page.locator('#kendali')).toBeInViewport();
  expect(external).toEqual([]);
  expect(await context.cookies()).toEqual([]);
});

test('Reduced motion and missing pages remain readable',async({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});
  await page.goto('/');
  await expect(page.locator('#fitur')).toHaveCSS('opacity','1');
  const response = await page.goto('/missing-page');
  expect(response.status()).toBe(404);
  await expect(page.getByRole('link',{name:'Kembali ke beranda'})).toBeVisible();
});
