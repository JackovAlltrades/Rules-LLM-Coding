const { PrismaClient } = require('@prisma/client');
const { faker } = require('@faker-js/faker');

const prisma = new PrismaClient();

const USER_COUNT = 10;
const POSTS_PER_USER = 3;

async function main() {
  console.log('Seeding database...');

  // Clear existing data (optional, be careful in production!)
  console.log('Deleting existing data...');
  // The order matters due to foreign key constraints
  await prisma.post.deleteMany();
  await prisma.profile.deleteMany();
  await prisma.user.deleteMany();
  console.log('Deleted existing data.');

  // Seed Users and their related data
  console.log(`Generating ${USER_COUNT} users...`);
  const userPromises = [];
  for (let i = 0; i < USER_COUNT; i++) {
    userPromises.push(
      prisma.user.create({
        data: {
          name: faker.person.fullName(),
          email: faker.internet.email({ firstName: `user${i}`, allowSpecialCharacters: false }).toLowerCase(), // Ensure unique & valid emails
          profile: {
            create: {
              bio: faker.lorem.sentence(),
            },
          },
          posts: {
            create: Array.from({ length: POSTS_PER_USER }).map(() => ({
              title: faker.lorem.words({ min: 3, max: 7 }),
              content: faker.lorem.paragraphs(2),
              published: faker.datatype.boolean(0.7), // 70% chance of being published
            })),
          },
        },
        include: { // Include related data in the result (optional)
          profile: true,
          posts: true,
        },
      })
    );
  }

  const users = await Promise.all(userPromises);
  console.log(`Successfully created ${users.length} users with profiles and posts.`);

}

main()
  .catch((e) => {
    console.error('Error during seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    console.log('Disconnecting Prisma Client...');
    await prisma.$disconnect();
    console.log('Seeding finished.');
  });

