import { db, passwordHash } from '../packages/shared/src/core';
async function main() {
  let text = '';
  for await (const chunk of process.stdin) text += chunk;
  const { email, password } = JSON.parse(text);
  if (
    typeof email !== 'string' ||
    !/^\S+@\S+\.\S+$/.test(email) ||
    typeof password !== 'string' ||
    password.length < 12 ||
    password.length > 256
  )
    throw new Error('Email hợp lệ; mật khẩu từ 12 đến 256 ký tự.');
  if (await db.adminUser.findUnique({ where: { email: email.toLowerCase() } }))
    throw new Error('Admin đã tồn tại; không ghi đè.');
  await db.adminUser.create({
    data: { email: email.toLowerCase(), passwordHash: passwordHash(password) },
  });
  console.log('Đã tạo admin.');
  await db.$disconnect();
  process.exit(0);
}
main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
