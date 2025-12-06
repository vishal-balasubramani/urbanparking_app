const { PrismaClient } = require('@prisma/client');
const crypto = require('crypto');

const prisma = new PrismaClient();

const parkingAreasData = [
  // ========== BENGALURU ==========
  {
    city: "Bengaluru",
    name: "UB City Premium Parking",
    totalSlots: 50,
    address: "24, Vittal Mallya Rd, KG Halli, Ashok Nagar, Bengaluru 560001",
    long: 77.5950,
    lat: 12.9708,
    features: ["Valet Parking", "Security", "EV Charging", "Covered", "Premium"],
    price_per_hour: 50.00,
    slotPrefix: "UBC"
  },
  {
    city: "Bengaluru",
    name: "Orion Mall Parking",
    totalSlots: 45,
    address: "Dr Rajkumar Rd, Rajajinagar, Bengaluru 560055",
    long: 77.5552,
    lat: 13.0107,
    features: ["Mall Parking", "Covered", "Multi-Level", "CCTV", "Lakeside"],
    price_per_hour: 30.00,
    slotPrefix: "ORM"
  },
  {
    city: "Bengaluru",
    name: "Phoenix Mall Whitefield",
    totalSlots: 50,
    address: "Whitefield Main Rd, Devasandra, Mahadevapura, Bengaluru 560048",
    long: 77.6970,
    lat: 12.9981,
    features: ["Mall Parking", "Covered", "Large Capacity", "Valet"],
    price_per_hour: 40.00,
    slotPrefix: "PMW"
  },
  {
    city: "Bengaluru",
    name: "Forum Mall Koramangala",
    totalSlots: 42,
    address: "Hosur Rd, Koramangala, Bengaluru 560095",
    long: 77.6225,
    lat: 12.9352,
    features: ["Mall Parking", "Basement", "PVR Cinema", "Covered"],
    price_per_hour: 35.00,
    slotPrefix: "FMK"
  },
  {
    city: "Bengaluru",
    name: "Airport Terminal Parking",
    totalSlots: 50,
    address: "Kempegowda International Airport, Devanahalli, Bengaluru 560300",
    long: 77.7068,
    lat: 13.1989,
    features: ["Airport", "Premium", "24x7", "Short-term", "Covered"],
    price_per_hour: 50.00,
    slotPrefix: "KIA"
  },
  {
    city: "Bengaluru",
    name: "Mantri Square Complex",
    totalSlots: 40,
    address: "Sampige Rd, Malleshwaram, Bengaluru 560003",
    long: 77.5706,
    lat: 12.9916,
    features: ["Mall Parking", "Metro Connected", "Covered", "Multi-Level"],
    price_per_hour: 30.00,
    slotPrefix: "MSM"
  },
  {
    city: "Bengaluru",
    name: "Garuda Mall Central",
    totalSlots: 38,
    address: "Magrath Rd, Ashok Nagar, Bengaluru 560025",
    long: 77.6087,
    lat: 12.9705,
    features: ["Central Location", "Covered", "CCTV"],
    price_per_hour: 40.00,
    slotPrefix: "GMR"
  },
  {
    city: "Bengaluru",
    name: "Brigade Road Plaza",
    totalSlots: 45,
    address: "Brigade Rd, Shanthala Nagar, Ashok Nagar, Bengaluru 560025",
    long: 77.6087,
    lat: 12.9716,
    features: ["Shopping District", "Central", "Covered"],
    price_per_hour: 45.00,
    slotPrefix: "BRP"
  },

  // ========== MUMBAI ==========
  {
    city: "Mumbai",
    name: "Phoenix Kurla Complex",
    totalSlots: 50,
    address: "LBS Marg, Kurla West, Mumbai 400070",
    long: 72.8889,
    lat: 19.0860,
    features: ["Mall Parking", "Covered", "Large Capacity", "Valet"],
    price_per_hour: 50.00,
    slotPrefix: "PMK"
  },
  {
    city: "Mumbai",
    name: "Infiniti Malad Hub",
    totalSlots: 42,
    address: "New Link Rd, Mindspace, Malad West, Mumbai 400064",
    long: 72.8432,
    lat: 19.1873,
    features: ["Mall Parking", "Covered", "Multi-Level"],
    price_per_hour: 40.00,
    slotPrefix: "IMM"
  },
  {
    city: "Mumbai",
    name: "Nariman Point Tower",
    totalSlots: 35,
    address: "B-2, Free Press Journal Marg, Nariman Point, Mumbai 400021",
    long: 72.8229,
    lat: 18.9287,
    features: ["Covered", "Staffed", "CCTV", "Multi-Level", "Business District"],
    price_per_hour: 60.00,
    slotPrefix: "NPM"
  },
  {
    city: "Mumbai",
    name: "BKC Business Bay",
    totalSlots: 35,
    address: "Bandra Kurla Complex, Bandra East, Mumbai 400051",
    long: 72.8697,
    lat: 19.0596,
    features: ["Business Hub", "CCTV", "Premium"],
    price_per_hour: 50.00,
    slotPrefix: "BKC"
  },
  {
    city: "Mumbai",
    name: "Airport Terminal 2 Plaza",
    totalSlots: 50,
    address: "Chhatrapati Shivaji Intl Airport, Vile Parle East, Mumbai 400099",
    long: 72.8656,
    lat: 19.0896,
    features: ["Airport", "24x7", "Multi-Level", "Premium"],
    price_per_hour: 80.00,
    slotPrefix: "MAT"
  },
  {
    city: "Mumbai",
    name: "Gateway Plaza Parking",
    totalSlots: 40,
    address: "Apollo Bandar, Colaba, Mumbai 400001",
    long: 72.8347,
    lat: 18.9220,
    features: ["Tourist Area", "Heritage Location", "CCTV"],
    price_per_hour: 50.00,
    slotPrefix: "GWP"
  },

  // ========== DELHI ==========
  {
    city: "Delhi",
    name: "DLF Saket Plaza",
    totalSlots: 48,
    address: "A-4, District Centre, Saket, New Delhi 110017",
    long: 77.2190,
    lat: 28.5285,
    features: ["Mall Parking", "Covered", "Premium"],
    price_per_hour: 50.00,
    slotPrefix: "DLF"
  },
  {
    city: "Delhi",
    name: "Select Citywalk Hub",
    totalSlots: 45,
    address: "A-3, District Centre, Saket, New Delhi 110017",
    long: 77.2190,
    lat: 28.5285,
    features: ["Mall Parking", "Covered", "Valet", "Premium"],
    price_per_hour: 50.00,
    slotPrefix: "SCS"
  },
  {
    city: "Delhi",
    name: "Connaught Circle Central",
    totalSlots: 35,
    address: "Connaught Place, New Delhi 110001",
    long: 77.2167,
    lat: 28.6315,
    features: ["Central Location", "Underground", "Security"],
    price_per_hour: 60.00,
    slotPrefix: "CPC"
  },
  {
    city: "Delhi",
    name: "Metro Station Parking",
    totalSlots: 40,
    address: "Kashmiri Gate Metro Station, New Delhi 110006",
    long: 77.2276,
    lat: 28.6675,
    features: ["Metro Connected", "CCTV", "Budget Friendly"],
    price_per_hour: 30.00,
    slotPrefix: "KGM"
  },
  {
    city: "Delhi",
    name: "Karol Bagh Market",
    totalSlots: 35,
    address: "Karol Bagh, New Delhi 110005",
    long: 77.1925,
    lat: 28.6519,
    features: ["Market Area", "Covered", "Security"],
    price_per_hour: 35.00,
    slotPrefix: "KBM"
  },
  {
    city: "Delhi",
    name: "IGI Airport Terminal 3",
    totalSlots: 50,
    address: "Indira Gandhi International Airport, New Delhi 110037",
    long: 77.0875,
    lat: 28.5562,
    features: ["Airport", "Multi-Level", "24x7", "Premium"],
    price_per_hour: 100.00,
    slotPrefix: "IGI"
  },

  // ========== CHENNAI ==========
  {
    city: "Chennai",
    name: "Express Avenue Plaza",
    totalSlots: 42,
    address: "Whites Rd, Royapettah, Chennai 600014",
    long: 80.2638,
    lat: 13.0578,
    features: ["Mall Parking", "Covered", "Central Location"],
    price_per_hour: 40.00,
    slotPrefix: "EAM"
  },
  {
    city: "Chennai",
    name: "Phoenix Velachery Mall",
    totalSlots: 48,
    address: "Velachery Main Rd, Velachery, Chennai 600042",
    long: 80.2209,
    lat: 12.9815,
    features: ["Mall Parking", "Large Capacity", "Covered", "Multi-Level"],
    price_per_hour: 35.00,
    slotPrefix: "PMC"
  },
  {
    city: "Chennai",
    name: "VR Chennai Complex",
    totalSlots: 40,
    address: "Jawaharlal Nehru Rd, Anna Nagar, Chennai 600040",
    long: 80.2159,
    lat: 13.0858,
    features: ["Mall Parking", "Premium", "Covered"],
    price_per_hour: 45.00,
    slotPrefix: "VRC"
  },
  {
    city: "Chennai",
    name: "Marina Beach Plaza",
    totalSlots: 38,
    address: "Marina Beach Rd, Chennai 600004",
    long: 80.2785,
    lat: 13.0499,
    features: ["Beach Area", "Open Parking", "Tourist Spot"],
    price_per_hour: 30.00,
    slotPrefix: "MBP"
  },
  {
    city: "Chennai",
    name: "Airport Arrival Terminal",
    totalSlots: 45,
    address: "Chennai International Airport, Tirusulam, Chennai 600027",
    long: 80.1693,
    lat: 12.9941,
    features: ["Airport", "24x7", "Multi-Level"],
    price_per_hour: 50.00,
    slotPrefix: "MAA"
  },

  // ========== HYDERABAD ==========
  {
    city: "Hyderabad",
    name: "Inorbit Cyberabad Mall",
    totalSlots: 45,
    address: "Inorbit Mall Rd, Mindspace, Madhapur, Hyderabad 500081",
    long: 78.3848,
    lat: 17.4375,
    features: ["Mall Parking", "IT Hub Area", "Covered", "Large Capacity"],
    price_per_hour: 40.00,
    slotPrefix: "IMC"
  },
  {
    city: "Hyderabad",
    name: "IKEA Shopping Complex",
    totalSlots: 42,
    address: "Hitec City Main Rd, Hyderabad 500081",
    long: 78.3626,
    lat: 17.4435,
    features: ["Retail Hub", "Large Area", "Family Friendly"],
    price_per_hour: 35.00,
    slotPrefix: "IKE"
  },
  {
    city: "Hyderabad",
    name: "GVK One Banjara",
    totalSlots: 40,
    address: "Road No. 1, Banjara Hills, Hyderabad 500034",
    long: 78.4490,
    lat: 17.4156,
    features: ["Mall Parking", "Premium Area", "Covered"],
    price_per_hour: 45.00,
    slotPrefix: "GVK"
  },
  {
    city: "Hyderabad",
    name: "Hitech City Metro Hub",
    totalSlots: 38,
    address: "Hitech City Main Rd, Hyderabad 500081",
    long: 78.3688,
    lat: 17.4485,
    features: ["IT Hub", "Metro Connected", "Corporate"],
    price_per_hour: 40.00,
    slotPrefix: "HTC"
  },
  {
    city: "Hyderabad",
    name: "Rajiv Gandhi Airport",
    totalSlots: 50,
    address: "Shamshabad, Hyderabad 500409",
    long: 78.4296,
    lat: 17.2403,
    features: ["Airport", "Multi-Level", "24x7"],
    price_per_hour: 60.00,
    slotPrefix: "RGI"
  },

  // ========== KOLKATA ==========
  {
    city: "Kolkata",
    name: "South City Mall Complex",
    totalSlots: 45,
    address: "Prince Anwar Shah Rd, Jadavpur, Kolkata 700068",
    long: 88.3666,
    lat: 22.5020,
    features: ["Mall Parking", "Covered", "Security", "Large Capacity"],
    price_per_hour: 35.00,
    slotPrefix: "SCM"
  },
  {
    city: "Kolkata",
    name: "Quest Ballygunge Plaza",
    totalSlots: 38,
    address: "Park Circus, Ballygunge, Kolkata 700017",
    long: 88.3731,
    lat: 22.5373,
    features: ["Mall Parking", "Premium", "Covered"],
    price_per_hour: 40.00,
    slotPrefix: "QMK"
  },
  {
    city: "Kolkata",
    name: "New Market Central",
    totalSlots: 35,
    address: "Lindsay Street, New Market Area, Kolkata 700087",
    long: 88.3507,
    lat: 22.5569,
    features: ["Market Area", "Historic Location", "Budget"],
    price_per_hour: 25.00,
    slotPrefix: "NMC"
  },
  {
    city: "Kolkata",
    name: "Howrah Station Plaza",
    totalSlots: 40,
    address: "Howrah Station Rd, Howrah, Kolkata 711101",
    long: 88.3426,
    lat: 22.5834,
    features: ["Railway Station", "24x7", "High Traffic"],
    price_per_hour: 30.00,
    slotPrefix: "HWH"
  },

  // ========== PUNE ==========
  {
    city: "Pune",
    name: "Phoenix Mall Viman Nagar",
    totalSlots: 48,
    address: "Nagar Rd, Viman Nagar, Pune 411014",
    long: 73.9146,
    lat: 18.5624,
    features: ["Mall Parking", "Large Capacity", "Covered", "Premium"],
    price_per_hour: 40.00,
    slotPrefix: "PMP"
  },
  {
    city: "Pune",
    name: "Seasons Magarpatta City",
    totalSlots: 42,
    address: "Magarpatta City, Hadapsar, Pune 411028",
    long: 73.9286,
    lat: 18.5089,
    features: ["Mall Parking", "IT Hub", "Covered"],
    price_per_hour: 30.00,
    slotPrefix: "SMM"
  },
  {
    city: "Pune",
    name: "FC Road Plaza",
    totalSlots: 35,
    address: "FC Rd, Deccan Gymkhana, Pune 411004",
    long: 73.8400,
    lat: 18.5168,
    features: ["Commercial Area", "Central Location", "Budget"],
    price_per_hour: 20.00,
    slotPrefix: "FCR"
  },

  // ========== NOIDA ==========
  {
    city: "Noida",
    name: "DLF Mall of India",
    totalSlots: 50,
    address: "Sector 18, Noida 201301",
    long: 77.3260,
    lat: 28.5673,
    features: ["Mall Parking", "Largest Mall", "Multi-Level", "Premium"],
    price_per_hour: 50.00,
    slotPrefix: "DMI"
  },

  // ========== GURGAON ==========
  {
    city: "Gurgaon",
    name: "Ambience Island Mall",
    totalSlots: 48,
    address: "NH-8, Ambience Island, Gurgaon 122002",
    long: 77.0969,
    lat: 28.5042,
    features: ["Mall Parking", "Premium", "Large Capacity", "Covered"],
    price_per_hour: 60.00,
    slotPrefix: "AMG"
  },
  {
    city: "Gurgaon",
    name: "Cyber City Corporate Hub",
    totalSlots: 45,
    address: "DLF Cyber City, Gurgaon 122002",
    long: 77.0871,
    lat: 28.4942,
    features: ["Office Complex", "Corporate", "Covered", "24x7"],
    price_per_hour: 40.00,
    slotPrefix: "DCC"
  }
];

async function main() {
  console.log(`\n========================================`);
  console.log(`🚀 Starting Database Seeding`);
  console.log(`========================================\n`);
  console.log(`Total parking areas to create: ${parkingAreasData.length}`);

  // --- CLEANUP: Clear existing data before seeding ---
  console.log(`\n🧹 Clearing existing data...`);

  await prisma.booking.deleteMany();
  console.log(`   ✓ Cleared bookings`);

  await prisma.parkingSlot.deleteMany();
  console.log(`   ✓ Cleared parking slots`);

  await prisma.parkingArea.deleteMany();
  console.log(`   ✓ Cleared parking areas`);

  // --- INSERT PARKING AREAS ---
  console.log(`\n📍 Creating Parking Areas...`);

  const areasForCreation = parkingAreasData.map(({ slotPrefix, ...rest }) => rest);

  const createdAreas = [];
  for (const area of areasForCreation) {
    const createdArea = await prisma.parkingArea.create({ data: area });
    createdAreas.push(createdArea);
    console.log(`   ✓ ${createdArea.city}: ${createdArea.name} (${createdArea.totalSlots} slots)`);
  }

  console.log(`\n   Total areas created: ${createdAreas.length}`);

  // --- INSERT PARKING SLOTS ---
  console.log(`\n🅿️  Creating Parking Slots...`);

  let totalSlotsCreated = 0;

  for (const area of createdAreas) {
    const dataRef = parkingAreasData.find(d => d.name === area.name);
    if (!dataRef) continue;

    const slotData = [];

    for (let i = 1; i <= area.totalSlots; i++) {
      const slotNumber = `${dataRef.slotPrefix}-${String(i).padStart(4, '0')}`;
      slotData.push({
        parkingId: area.id,
        slotNumber: slotNumber,
      });
    }

    const result = await prisma.parkingSlot.createMany({
      data: slotData,
    });

    totalSlotsCreated += result.count;
    console.log(`   ✓ ${area.name}: ${result.count} slots`);
  }

  // --- SUMMARY ---
  console.log(`\n========================================`);
  console.log(`✅ Seeding Complete!`);
  console.log(`========================================`);
  console.log(`   📍 Parking Areas: ${createdAreas.length}`);
  console.log(`   🅿️  Parking Slots: ${totalSlotsCreated}`);
  console.log(`   🏙️  Cities: ${[...new Set(parkingAreasData.map(p => p.city))].length}`);
  console.log(`========================================\n`);
}

main()
  .catch((e) => {
    console.error(`\n❌ Seeding Error:`, e.message);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
