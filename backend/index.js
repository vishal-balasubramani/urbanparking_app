require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const Razorpay = require('razorpay');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cookieParser = require('cookie-parser');
const { OAuth2Client } = require('google-auth-library');

const app = express();
const prisma = new PrismaClient({
  log: ['query', 'error', 'warn'],
});

// Google OAuth Client
const googleClient = new OAuth2Client(
  process.env.GOOGLE_CLIENT_ID || 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
);

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(cookieParser());

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1] || req.cookies.token;

  if (!token) {
    return res.status(401).json({ error: 'Access denied' });
  }

  try {
    const verified = jwt.verify(token, JWT_SECRET);
    req.userId = verified.userId;
    next();
  } catch (error) {
    res.status(403).json({ error: 'Invalid token' });
  }
};

// Initialize Razorpay
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID || 'rzp_test_rN3ysbintURr2f',
  key_secret: process.env.RAZORPAY_KEY_SECRET || '0BhzmL3LO4S2BoNdOoxt5YkM',
});

// ==================== AUTH ROUTES ====================

// Register with email/password
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;

    if (!name || !email || !phone || !password) {
      return res.status(400).json({ error: 'All fields are required' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [{ email }, { phone }]
      }
    });

    if (existingUser) {
      return res.status(400).json({
        error: existingUser.email === email
          ? 'Email already registered'
          : 'Phone number already registered'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        name,
        email,
        phone,
        password: hashedPassword,
      },
    });

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
    const { password: _, ...userWithoutPassword } = user;

    res.status(201).json({
      user: userWithoutPassword,
      token,
    });
  } catch (error) {
    console.error('Error registering user:', error);
    res.status(500).json({ error: error.message });
  }
});

// Login with email/password
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const user = await prisma.user.findUnique({ where: { email } });

    if (!user || !user.password) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const validPassword = await bcrypt.compare(password, user.password);

    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
    const { password: _, ...userWithoutPassword } = user;

    res.json({
      user: userWithoutPassword,
      token,
    });
  } catch (error) {
    console.error('Error logging in:', error);
    res.status(500).json({ error: error.message });
  }
});

// Google OAuth login/register
app.post('/api/auth/google', async (req, res) => {
  try {
    const { googleId, email, name, profilePic, idToken } = req.body;

    console.log('Google auth request:', { googleId, email, name });

    if (!googleId || !email) {
      return res.status(400).json({ error: 'Google ID and email are required' });
    }

    let user = await prisma.user.findUnique({ where: { googleId } });

    if (!user) {
      user = await prisma.user.findUnique({ where: { email } });

      if (user) {
        user = await prisma.user.update({
          where: { email },
          data: { googleId, profilePic },
        });
      } else {
        user = await prisma.user.create({
          data: {
            name: name || 'Google User',
            email,
            googleId,
            profilePic,
            phone: `GOOGLE_${Date.now()}`,
            password: null,
          },
        });
      }
    } else {
      if (profilePic && user.profilePic !== profilePic) {
        user = await prisma.user.update({
          where: { id: user.id },
          data: { profilePic },
        });
      }
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
    const { password: _, ...userWithoutPassword } = user;

    console.log('Google auth successful for user:', user.email);

    res.json({
      user: userWithoutPassword,
      token,
    });
  } catch (error) {
    console.error('Error with Google auth:', error);
    res.status(500).json({ error: error.message });
  }
});

// Apple OAuth login/register
app.post('/api/auth/apple', async (req, res) => {
  try {
    const { appleId, email, name, identityToken } = req.body;

    console.log('Apple auth request:', { appleId, email, name });

    if (!appleId) {
      return res.status(400).json({ error: 'Apple ID is required' });
    }

    let user = await prisma.user.findUnique({ where: { appleId } });

    if (!user) {
      const userEmail = email || `${appleId}@appleid.apple.com`;

      user = await prisma.user.create({
        data: {
          name: name || 'Apple User',
          email: userEmail,
          appleId,
          phone: `APPLE_${Date.now()}`,
          password: null,
        },
      });
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
    const { password: _, ...userWithoutPassword } = user;

    console.log('Apple auth successful for user:', user.email);

    res.json({
      user: userWithoutPassword,
      token,
    });
  } catch (error) {
    console.error('Error with Apple auth:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get current user
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        profilePic: true,
        googleId: true,
        appleId: true,
        feedback: true,
        isGuest: true,
        createdAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(user);
  } catch (error) {
    console.error('Error getting user:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update user profile
app.put('/api/auth/profile', authenticateToken, async (req, res) => {
  try {
    const { name, phone } = req.body;

    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;

    const user = await prisma.user.update({
      where: { id: req.userId },
      data: updateData,
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        profilePic: true,
      },
    });

    res.json(user);
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ error: error.message });
  }
});

// Logout
app.post('/api/auth/logout', (req, res) => {
  res.json({ message: 'Logged out successfully' });
});

// ==================== PARKING AREAS ====================

// Get all cities
app.get('/api/cities', async (req, res) => {
  try {
    const cities = await prisma.parkingArea.findMany({
      select: { city: true },
      distinct: ['city']
    });
    res.json(cities.map(c => c.city));
  } catch (error) {
    console.error('Error fetching cities:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get parking areas by city (optimized)
app.get('/api/parking-areas', async (req, res) => {
  try {
    const { city } = req.query;
    const where = city ? { city } : {};

    const areas = await prisma.parkingArea.findMany({
      where,
      select: {
        id: true,
        city: true,
        name: true,
        totalSlots: true,
        address: true,
        long: true,
        lat: true,
        features: true,
        price_per_hour: true,
      }
    });

    res.json(areas);
  } catch (error) {
    console.error('Error fetching parking areas:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get parking area details with real-time availability
app.get('/api/parking-areas/:id/details', async (req, res) => {
  try {
    const { id } = req.params;
    const { startTime, endTime } = req.query;

    const area = await prisma.parkingArea.findUnique({
      where: { id: parseInt(id) },
    });

    if (!area) {
      return res.status(404).json({ error: 'Parking area not found' });
    }

    const totalSlots = area.totalSlots;
    let bookedCount = 0;
    let availableSlots = totalSlots;

    if (startTime && endTime) {
      const bookedSlots = await prisma.booking.findMany({
        where: {
          slot: { parkingId: parseInt(id) },
          bookingStatus: { in: ['PENDING', 'CONFIRMED'] },
          OR: [
            {
              AND: [
                { startTime: { lte: new Date(startTime) } },
                { endTime: { gt: new Date(startTime) } }
              ]
            },
            {
              AND: [
                { startTime: { lt: new Date(endTime) } },
                { endTime: { gte: new Date(endTime) } }
              ]
            }
          ]
        },
        select: { slotId: true },
        distinct: ['slotId']
      });
      bookedCount = bookedSlots.length;
      availableSlots = totalSlots - bookedCount;
    }

    res.json({
      ...area,
      availableSlots,
      bookedSlots: bookedCount,
      occupancyRate: ((bookedCount / totalSlots) * 100).toFixed(1),
    });
  } catch (error) {
    console.error('Error fetching parking details:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get reviews (mock for now)
app.get('/api/parking-areas/:id/reviews', async (req, res) => {
  try {
    const mockReviews = [
      {
        id: 1,
        userName: 'Rajesh Kumar',
        rating: 5,
        comment: 'Excellent parking facility with great security.',
        date: '2025-11-28',
      },
      {
        id: 2,
        userName: 'Priya Sharma',
        rating: 4,
        comment: 'Good location and clean. Slightly expensive.',
        date: '2025-11-25',
      },
      {
        id: 3,
        userName: 'Amit Patel',
        rating: 5,
        comment: 'Best parking in the area. EV charging available!',
        date: '2025-11-20',
      },
    ];

    res.json(mockReviews);
  } catch (error) {
    console.error('Error fetching reviews:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single parking area with available slots count
app.get('/api/parking-areas/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { startTime, endTime } = req.query;

    const area = await prisma.parkingArea.findUnique({
      where: { id: parseInt(id) },
      include: { slots: true }
    });

    if (!area) {
      return res.status(404).json({ error: 'Parking area not found' });
    }

    let bookedCount = 0;
    if (startTime && endTime) {
      const bookedSlots = await prisma.booking.findMany({
        where: {
          slot: { parkingId: parseInt(id) },
          bookingStatus: { in: ['PENDING', 'CONFIRMED'] },
          OR: [
            {
              AND: [
                { startTime: { lte: new Date(startTime) } },
                { endTime: { gt: new Date(startTime) } }
              ]
            },
            {
              AND: [
                { startTime: { lt: new Date(endTime) } },
                { endTime: { gte: new Date(endTime) } }
              ]
            }
          ]
        },
        select: { slotId: true },
        distinct: ['slotId']
      });
      bookedCount = bookedSlots.length;
    }

    res.json({
      ...area,
      availableSlots: area.totalSlots - bookedCount
    });
  } catch (error) {
    console.error('Error fetching parking area:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== SLOTS ====================

// Get available slots for a parking area
app.get('/api/parking-areas/:id/available-slots', async (req, res) => {
  try {
    const { id } = req.params;
    const { startTime, endTime } = req.query;

    if (!startTime || !endTime) {
      return res.status(400).json({ error: 'startTime and endTime are required' });
    }

    const allSlots = await prisma.parkingSlot.findMany({
      where: { parkingId: parseInt(id) }
    });

    const bookedSlots = await prisma.booking.findMany({
      where: {
        slot: { parkingId: parseInt(id) },
        bookingStatus: { in: ['PENDING', 'CONFIRMED'] },
        OR: [
          {
            AND: [
              { startTime: { lte: new Date(startTime) } },
              { endTime: { gt: new Date(startTime) } }
            ]
          },
          {
            AND: [
              { startTime: { lt: new Date(endTime) } },
              { endTime: { gte: new Date(endTime) } }
            ]
          }
        ]
      },
      select: { slotId: true }
    });

    const bookedIds = bookedSlots.map(b => b.slotId);
    const availableSlots = allSlots.filter(slot => !bookedIds.includes(slot.id));

    res.json(availableSlots);
  } catch (error) {
    console.error('Error fetching available slots:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get slots with status for a parking area
app.get('/api/parking-areas/:id/slots-status', async (req, res) => {
  try {
    const { id } = req.params;
    const { startTime, endTime } = req.query;

    if (!startTime || !endTime) {
      return res.status(400).json({ error: 'startTime and endTime are required' });
    }

    const allSlots = await prisma.parkingSlot.findMany({
      where: { parkingId: parseInt(id) },
      orderBy: { slotNumber: 'asc' }
    });

    const bookedSlots = await prisma.booking.findMany({
      where: {
        slot: { parkingId: parseInt(id) },
        bookingStatus: { in: ['PENDING', 'CONFIRMED'] },
        OR: [
          {
            AND: [
              { startTime: { lte: new Date(startTime) } },
              { endTime: { gt: new Date(startTime) } }
            ]
          },
          {
            AND: [
              { startTime: { lt: new Date(endTime) } },
              { endTime: { gte: new Date(endTime) } }
            ]
          }
        ]
      },
      select: { slotId: true }
    });

    const bookedSlotIds = new Set(bookedSlots.map(b => b.slotId));

    const slotsWithStatus = allSlots.map(slot => {
      let slotType = 'REGULAR';
      if (slot.slotNumber.includes('EV')) {
        slotType = 'EV';
      } else if (slot.slotNumber.includes('DIS') || slot.slotNumber.includes('H')) {
        slotType = 'DISABLED';
      }

      return {
        ...slot,
        status: bookedSlotIds.has(slot.id) ? 'OCCUPIED' : 'AVAILABLE',
        type: slotType
      };
    });

    res.json(slotsWithStatus);
  } catch (error) {
    console.error('Error fetching slots status:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== BOOKINGS ====================

// Create pending booking
// ==================== BOOKINGS ====================

// Create pending booking
app.post('/api/bookings', async (req, res) => {
  console.log('\n================ NEW BOOKING REQUEST ================');
  try {
    console.log('Request body:', JSON.stringify(req.body, null, 2));

    const {
      slotId,
      userId,
      startTime,
      endTime,
      vehicle_number,
      phone,
    } = req.body;

    // Validate input
    if (!slotId || !startTime || !endTime || !phone) {
      console.log('Missing required fields');
      return res.status(400).json({
        error: 'Missing required fields',
        received: { slotId, userId, startTime, endTime, vehicle_number, phone },
      });
    }

    console.log('Step 1: Finding slot with ID', slotId);
    const slot = await prisma.parkingSlot.findUnique({
      where: { id: parseInt(slotId) },
      include: { parkingArea: true },
    });

    if (!slot) {
      console.log('Slot not found with ID', slotId);
      return res.status(404).json({ error: 'Slot not found' });
    }

    console.log('Slot found:', slot.slotNumber, 'at', slot.parkingArea.name);

    console.log('Step 2: Checking for conflicts...');
    const conflict = await prisma.booking.findFirst({
      where: {
        slotId: parseInt(slotId),
        bookingStatus: { in: ['PENDING', 'CONFIRMED'] },
        OR: [
          {
            startTime: { lte: new Date(startTime) },
            endTime: { gt: new Date(startTime) },
          },
          {
            startTime: { lt: new Date(endTime) },
            endTime: { gte: new Date(endTime) },
          },
        ],
      },
    });

    if (conflict) {
      console.log('Slot conflict found! Existing booking', conflict.id);
      return res
        .status(409)
        .json({ error: 'Slot not available for selected time' });
    }

    console.log('No conflicts found');
    console.log('Step 3: Calculating amount...');

    const startDate = new Date(startTime);
    const endDate = new Date(endTime);
    const hours = Math.ceil(
      (endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60)
    );
    const amount = hours * slot.parkingArea.price_per_hour;

    console.log('Duration:', hours, 'hours');
    console.log('Price per hour:', slot.parkingArea.price_per_hour);
    console.log('Total amount:', amount);

    // ✅ Critical: correct data shape for Prisma schema
    const bookingData = {
      bookind_id: crypto.randomUUID(),        // your schema field
      slotId: parseInt(slotId),
      userId: userId ? parseInt(userId) : null, // no hard-coded 1
      startTime: startDate,
      endTime: endDate,
      vehicle_number: vehicle_number || null,
      phone,
      amount,
      bookingStatus: 'PENDING',
      paymentStatus: 'PENDING',
      expiresAt: new Date(Date.now() + 15 * 60 * 1000),
      entryScanned: false,
      entryTime: null,
      exitScanned: false,
      exitTime: null,
      active: false,
      status: 'available',
    };

    console.log('Step 4: Creating booking with data');
    console.log(JSON.stringify(bookingData, null, 2));

    const booking = await prisma.booking.create({
      data: bookingData,
      include: {
        slot: {
          include: { parkingArea: true },
        },
      },
    });

    console.log('\n=============== BOOKING CREATED SUCCESSFULLY! ===============');
    console.log('Booking ID:', booking.id);
    console.log('Booking UUID:', booking.bookind_id);
    console.log('User ID:', booking.userId);
    console.log('Slot:', booking.slot.slotNumber);
    console.log('Amount:', booking.amount);
    console.log('Status:', booking.bookingStatus);

    res.status(201).json(booking);
  } catch (error) {
    console.log('\n=============== ERROR CREATING BOOKING ===============');
    console.log('Error message:', error.message);
    console.log('Error code:', error.code);
    console.log('Error stack:', error.stack);
    res.status(500).json({
      error: error.message,
      code: error.code,
      details: error.toString(),
    });
  }
});


// Confirm booking after payment
app.post('/api/bookings/:id/confirm', async (req, res) => {
  try {
    const { id } = req.params;
    const { paymentId, paymentMethod } = req.body;

    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(id) }
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.bookingStatus !== 'PENDING') {
      return res.status(400).json({ error: 'Booking is not in pending state' });
    }

    if (booking.expiresAt && new Date() > booking.expiresAt) {
      await prisma.booking.update({
        where: { id: parseInt(id) },
        data: { bookingStatus: 'EXPIRED' }
      });
      return res.status(400).json({ error: 'Booking expired' });
    }

    const confirmedBooking = await prisma.booking.update({
      where: { id: parseInt(id) },
      data: {
        bookingStatus: 'CONFIRMED',
        paymentStatus: 'PAID',
        paymentId,
        paymentMethod
      },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    res.json(confirmedBooking);
  } catch (error) {
    console.error('Error confirming booking:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get user bookings - ✅ UPDATED WITH FULL INCLUDE
app.get('/api/users/:userId/bookings', async (req, res) => {
  try {
    const { userId } = req.params;

    console.log('\n========================================');
    console.log('📋 FETCHING USER BOOKINGS');
    console.log('========================================');
    console.log('User ID:', userId);

    const bookings = await prisma.booking.findMany({
      where: { userId: parseInt(userId) },
      include: {
        slot: {
          include: {
            parkingArea: true  // ✅ CRITICAL: Include parking area
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    console.log(`✅ Found ${bookings.length} bookings`);

    // Log booking statuses
    const statusCounts = {};
    bookings.forEach(b => {
      statusCounts[b.bookingStatus] = (statusCounts[b.bookingStatus] || 0) + 1;
    });

    console.log('📊 Booking statuses:', statusCounts);

    // Log sample booking structure
    if (bookings.length > 0) {
      console.log('📋 Sample booking structure:');
      console.log(JSON.stringify({
        id: bookings[0].id,
        bookingStatus: bookings[0].bookingStatus,
        slot: {
          slotNumber: bookings[0].slot.slotNumber,
          parkingArea: {
            name: bookings[0].slot.parkingArea.name,
            city: bookings[0].slot.parkingArea.city
          }
        }
      }, null, 2));
    }

    console.log('========================================\n');

    res.json(bookings);
  } catch (error) {
    console.error('❌ Error fetching user bookings:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single booking
app.get('/api/bookings/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(id) },
      include: {
        slot: {
          include: { parkingArea: true }
        },
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true
          }
        }
      }
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    res.json(booking);
  } catch (error) {
    console.error('Error fetching booking:', error);
    res.status(500).json({ error: error.message });
  }
});

// Cancel booking
app.post('/api/bookings/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(id) }
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.bookingStatus === 'COMPLETED' || booking.bookingStatus === 'CANCELLED') {
      return res.status(400).json({ error: 'Cannot cancel this booking' });
    }

    const cancelledBooking = await prisma.booking.update({
      where: { id: parseInt(id) },
      data: {
        bookingStatus: 'CANCELLED',
        paymentStatus: booking.paymentStatus === 'PAID' ? 'REFUNDED' : 'FAILED'
      },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    res.json(cancelledBooking);
  } catch (error) {
    console.error('Error cancelling booking:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== RAZORPAY PAYMENT ====================

// Create Razorpay order
app.post('/api/bookings/:id/create-order', async (req, res) => {
  try {
    const { id } = req.params;

    console.log('💳 Creating Razorpay order for booking:', id);

    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(id) },
    });

    if (!booking) {
      console.log('❌ Booking not found:', id);
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.bookingStatus !== 'PENDING') {
      console.log('❌ Booking is not pending:', booking.bookingStatus);
      return res.status(400).json({ error: 'Booking is not pending' });
    }

    const order = await razorpay.orders.create({
      amount: Math.round(booking.amount * 100),
      currency: 'INR',
      receipt: `booking_${booking.id}`,
      notes: {
        bookingId: booking.id,
        slotId: booking.slotId,
      },
    });

    console.log('✅ Razorpay order created:', order.id);

    res.json({
      orderId: order.id,
      amount: booking.amount,
      currency: 'INR',
      keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_rN3ysbintURr2f',
    });
  } catch (error) {
    console.error('Error creating Razorpay order:', error);
    res.status(500).json({ error: error.message });
  }
});

// Verify payment and confirm booking
app.post('/api/bookings/:id/verify-payment', async (req, res) => {
  console.log('\n========================================');
  console.log('💳 PAYMENT VERIFICATION REQUEST');
  console.log('========================================');

  try {
    const { id } = req.params;
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body;

    console.log('Booking ID:', id);
    console.log('Order ID:', razorpayOrderId);
    console.log('Payment ID:', razorpayPaymentId);

    const generatedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '0BhzmL3LO4S2BoNdOoxt5YkM')
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    console.log('Generated signature:', generatedSignature);
    console.log('Received signature:', razorpaySignature);

    if (generatedSignature !== razorpaySignature) {
      console.log('❌ Signature mismatch!');
      return res.status(400).json({ error: 'Invalid payment signature' });
    }

    console.log('✅ Signature verified');
    console.log('🔍 Updating booking to CONFIRMED...');

    const confirmedBooking = await prisma.booking.update({
      where: { id: parseInt(id) },
      data: {
        bookingStatus: 'CONFIRMED',
        paymentStatus: 'PAID',
        paymentId: razorpayPaymentId,
        paymentMethod: 'RAZORPAY',
      },
      include: {
        slot: {
          include: { parkingArea: true },
        },
      },
    });

    console.log('========================================');
    console.log('✅ BOOKING CONFIRMED SUCCESSFULLY!');
    console.log('========================================');
    console.log('Booking ID:', confirmedBooking.id);
    console.log('Status:', confirmedBooking.bookingStatus);
    console.log('Payment Status:', confirmedBooking.paymentStatus);
    console.log('Payment ID:', confirmedBooking.paymentId);
    console.log('========================================\n');

    res.json(confirmedBooking);
  } catch (error) {
    console.log('========================================');
    console.log('❌ ERROR VERIFYING PAYMENT');
    console.log('========================================');
    console.log('Error:', error.message);
    console.log('Stack:', error.stack);
    console.log('========================================\n');

    res.status(500).json({ error: error.message });
  }
});

// ==================== TEST ENDPOINT ====================

// Create test booking (temporary - for testing)
app.post('/api/test/create-booking', async (req, res) => {
  try {
    const slot = await prisma.parkingSlot.findFirst({
      include: { parkingArea: true }
    });

    if (!slot) {
      return res.status(404).json({ error: 'No slots available. Please run seed first.' });
    }

    const booking = await prisma.booking.create({
      data: {
        bookind_id: crypto.randomUUID(),
        userId: 1,
        slotId: slot.id,
        startTime: new Date(),
        endTime: new Date(Date.now() + 2 * 60 * 60 * 1000),
        vehicle_number: 'TEST1234',
        phone: '9999999999',
        amount: 100,
        bookingStatus: 'CONFIRMED',
        paymentStatus: 'PAID',
      },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    console.log('✅ Test booking created:', booking.id);
    res.json(booking);
  } catch (error) {
    console.error('Error creating test booking:', error);
    res.status(500).json({ error: error.message });
  }
});
// Get booking status for QR display
app.get('/api/bookings/:id/qr-status', async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(id) },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    const now = new Date();
    const startTime = new Date(booking.startTime);
    const endTime = new Date(booking.endTime);

    // Determine if QR should be shown
    let showQR = false;
    let qrStatus = 'INACTIVE';
    let statusMessage = '';

    if (booking.bookingStatus === 'CANCELLED') {
      showQR = false;
      qrStatus = 'CANCELLED';
      statusMessage = booking.refundAmount
        ? `Cancelled - Refund â‚¹${booking.refundAmount.toFixed(0)} initiated`
        : 'Booking Cancelled';
    } else if (booking.bookingStatus === 'EXPIRED') {
      showQR = false;
      qrStatus = 'EXPIRED';
      statusMessage = 'Booking Expired';
    } else if (booking.bookingStatus === 'COMPLETED') {
      showQR = false;
      qrStatus = 'COMPLETED';
      statusMessage = 'Parking Session Completed';
    } else if (booking.bookingStatus === 'CONFIRMED') {
      // Show QR only during active session (between start and end time)
      if (now >= startTime && now <= endTime) {
        showQR = true;
        qrStatus = 'ACTIVE';
        statusMessage = booking.entryScanned
          ? 'Active - Vehicle Inside'
          : 'Active - Scan at Entry';
      } else if (now < startTime) {
        showQR = false;
        qrStatus = 'UPCOMING';
        const minutesUntil = Math.ceil((startTime - now) / (1000 * 60));
        statusMessage = `Available in ${minutesUntil} minutes`;
      } else {
        showQR = false;
        qrStatus = 'EXPIRED';
        statusMessage = 'Session Ended';
      }
    }

    res.json({
      showQR,
      qrStatus,
      statusMessage,
      booking: {
        id: booking.id,
        bookingStatus: booking.bookingStatus,
        paymentStatus: booking.paymentStatus,
        startTime: booking.startTime,
        endTime: booking.endTime,
        refundAmount: booking.refundAmount,
        entryScanned: booking.entryScanned,
        exitScanned: booking.exitScanned,
        slot: booking.slot,
      }
    });

  } catch (error) {
    console.error('Error checking QR status:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update cancel endpoint to include refund
app.post('/api/bookings/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;

    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(id) }
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.bookingStatus === 'COMPLETED' || booking.bookingStatus === 'CANCELLED') {
      return res.status(400).json({ error: 'Cannot cancel this booking' });
    }

    // Calculate refund if not entered yet
    let refundAmount = 0;
    let refundPercentage = 0;

    if (booking.paymentStatus === 'PAID' && !booking.entryScanned) {
      const now = new Date();
      const endTime = new Date(booking.endTime);

      // If booking time hasn't ended, calculate refund
      if (now < endTime) {
        const startTime = new Date(booking.startTime);
        const hoursUntilStart = (startTime - now) / (1000 * 60 * 60);

        if (hoursUntilStart > 2) {
          refundPercentage = 100;
        } else if (hoursUntilStart > 1) {
          refundPercentage = 75;
        } else if (hoursUntilStart > 0.5) {
          refundPercentage = 50;
        } else if (hoursUntilStart > 0) {
          refundPercentage = 25;
        } else if (now < endTime) {
          refundPercentage = 50; // During session but not entered
        }

        refundAmount = (booking.amount * refundPercentage) / 100;
      }
    }

    const cancelledBooking = await prisma.booking.update({
      where: { id: parseInt(id) },
      data: {
        bookingStatus: 'CANCELLED',
        paymentStatus: refundAmount > 0
          ? (refundPercentage === 100 ? 'REFUNDED' : 'PARTIAL_REFUND')
          : booking.paymentStatus === 'PAID' ? 'REFUNDED' : 'FAILED',
        refundAmount: refundAmount > 0 ? refundAmount : null,
        refundedAt: refundAmount > 0 ? new Date() : null,
      },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    res.json({
      ...cancelledBooking,
      refundPercentage,
      message: refundAmount > 0
        ? `Booking cancelled. â‚¹${refundAmount.toFixed(0)} refund initiated.`
        : 'Booking cancelled.'
    });

  } catch (error) {
    console.error('Error cancelling booking:', error);
    res.status(500).json({ error: error.message });
  }
});
// Cancel booking with refund (before entry)
app.post('/api/bookings/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    const bookingId = parseInt(id);

    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.bookingStatus === 'COMPLETED' || booking.bookingStatus === 'CANCELLED') {
      return res.status(400).json({ error: 'Cannot cancel this booking' });
    }

    // Check if user has already entered
    if (booking.entryScanned) {
      return res.status(400).json({
        error: 'Cannot cancel booking after entering the parking area.',
        canRefund: false
      });
    }

    // Calculate refund if payment was made
    let refundAmount = 0;
    let refundPercentage = 0;

    if (booking.paymentStatus === 'PAID' && !booking.entryScanned) {
      const now = new Date();
      const endTime = new Date(booking.endTime);

      if (now < endTime) {
        const startTime = new Date(booking.startTime);
        const hoursUntilStart = (startTime - now) / (1000 * 60 * 60);

        // Refund policy
        if (hoursUntilStart > 2) {
          refundPercentage = 100;
        } else if (hoursUntilStart > 1) {
          refundPercentage = 75;
        } else if (hoursUntilStart > 0.5) {
          refundPercentage = 50;
        } else if (hoursUntilStart > 0) {
          refundPercentage = 25;
        } else if (now < endTime) {
          refundPercentage = 50;
        }

        refundAmount = (booking.amount * refundPercentage) / 100;
      }
    }

    // Process Razorpay refund
    let razorpayRefund = null;
    let refundStatus = 'SUCCESS';

    if (booking.paymentId && booking.paymentMethod === 'RAZORPAY' && refundAmount > 0) {
      try {
        console.log('ðŸ”„ Processing Razorpay refund...');
        console.log('Payment ID:', booking.paymentId);
        console.log('Refund Amount:', refundAmount);

        razorpayRefund = await razorpay.payments.refund(booking.paymentId, {
          amount: Math.round(refundAmount * 100),
          speed: 'normal',
          notes: {
            bookingId: booking.id,
            reason: 'Cancellation before entry',
            refundPercentage: refundPercentage
          }
        });

        console.log('âœ… Razorpay refund initiated:', razorpayRefund.id);

      } catch (error) {
        console.error('âŒ Razorpay refund error:', error.error || error.message);

        // âœ… Handle test mode balance error gracefully
        if (error.error && error.error.code === 'BAD_REQUEST_ERROR' &&
            error.error.description.includes('balance')) {
          console.log('âš ï¸ Test mode: Insufficient balance. Marking refund as pending.');
          refundStatus = 'PENDING'; // Mark as pending instead of failing
        } else {
          refundStatus = 'FAILED';
        }
      }
    }

    // Update booking
    const updatedBooking = await prisma.booking.update({
      where: { id: bookingId },
      data: {
        bookingStatus: 'CANCELLED',
        paymentStatus: refundAmount > 0
          ? (refundPercentage === 100 ? 'REFUNDED' : 'PARTIAL_REFUND')
          : 'FAILED',
        refundId: razorpayRefund?.id || null,
        refundAmount: refundAmount > 0 ? refundAmount : null,
        refundedAt: refundAmount > 0 ? new Date() : null,
      },
      include: {
        slot: {
          include: { parkingArea: true }
        }
      }
    });

    console.log('âœ… Booking cancelled:', updatedBooking.id);

    res.json({
      message: refundAmount > 0
        ? `Booking cancelled. ${refundPercentage}% refund ${refundStatus === 'PENDING' ? 'pending' : 'initiated'}.`
        : 'Booking cancelled.',
      booking: updatedBooking,
      refundAmount: refundAmount,
      refundPercentage: refundPercentage,
      refundStatus: refundStatus,
      refundId: razorpayRefund?.id,
      estimatedRefundTime: refundAmount > 0 ? '5-7 business days' : null
    });

  } catch (error) {
    console.error('âŒ Error cancelling booking:', error);
    res.status(500).json({
      error: 'Failed to cancel booking',
      details: error.message
    });
  }
});
// 1) Create Razorpay order for extension
// POST /api/bookings/:id/create-extension-order
app.post('/api/bookings/:id/create-extension-order', async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    const { extraMinutes } = req.body;

    if (!bookingId || !extraMinutes || extraMinutes <= 0) {
      return res.status(400).json({ error: 'Invalid booking or extraMinutes' });
    }

    // Get booking with slot and parkingArea (for price_per_hour)
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        slot: {
          include: { parkingArea: true },
        },
      },
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }
    if (!booking.slot || !booking.slot.parkingArea) {
      return res
        .status(400)
        .json({ error: 'Parking info missing for this booking' });
    }

    const pricePerHour = booking.slot.parkingArea.price_per_hour || 0;
    if (pricePerHour <= 0) {
      return res.status(400).json({ error: 'Invalid price_per_hour' });
    }

    // Compute extension amount in INR
    const extraHours = extraMinutes / 60;
    const amount = Math.round(pricePerHour * extraHours); // INR

    if (amount <= 0) {
      return res
        .status(400)
        .json({ error: 'Extension amount must be greater than 0' });
    }

    // Create Razorpay order (amount in paise)
    const razorpayOrder = await razorpay.orders.create({
      amount: amount * 100, // paise
      currency: 'INR',
      receipt: `booking-ext-${bookingId}-${Date.now()}`,
      notes: {
        bookingId: bookingId.toString(),
        extraMinutes: extraMinutes.toString(),
        type: 'extension',
      },
    });

    // No separate extension table: just respond for now
    res.json({
      orderId: razorpayOrder.id,
      amount, // INR (Flutter multiplies by 100 again when opening Razorpay)
      keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_rN3ysbintURr2f',
    });
  } catch (error) {
    console.error('Error creating extension order:', error);
    res.status(500).json({ error: 'Failed to create extension order' });
  }
});

// 2) Confirm extension after Razorpay payment
// POST /api/bookings/:id/confirm-extension
app.post('/api/bookings/:id/confirm-extension', async (req, res) => {
  try {
    const bookingId = parseInt(req.params.id, 10);
    const {
      extraMinutes,
      razorpayPaymentId,
      razorpayOrderId,
      razorpaySignature,
    } = req.body;

    if (
      !bookingId ||
      !extraMinutes ||
      !razorpayPaymentId ||
      !razorpayOrderId ||
      !razorpaySignature
    ) {
      return res.status(400).json({ error: 'Missing payment details' });
    }

    // Verify Razorpay signature
    const body = razorpayOrderId + '|' + razorpayPaymentId;
    const expectedSignature = crypto
      .createHmac(
        'sha256',
        process.env.RAZORPAY_KEY_SECRET || '0BhzmL3LO4S2BoNdOoxt5YkM',
      )
      .update(body.toString())
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      return res.status(400).json({ error: 'Invalid payment signature' });
    }

    // Load booking
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Extend endTime
    const currentEnd = booking.endTime;
    const newEnd = new Date(
      currentEnd.getTime() + extraMinutes * 60 * 1000,
    );

    // Update amount (optional â€“ add extra charge)
    const updatedBooking = await prisma.booking.update({
      where: { id: bookingId },
      data: {
        endTime: newEnd,
        paymentStatus: 'PAID',
        paymentId: razorpayPaymentId,
        // if you want to add the extra amount to existing total:
        // amount: booking.amount + computedExtraAmount
      },
      include: {
        slot: {
          include: { parkingArea: true },
        },
      },
    });

    res.json({ booking: updatedBooking });
  } catch (error) {
    console.error('Error confirming extension:', error);
    res.status(500).json({ error: 'Failed to confirm extension' });
  }
});


// ==================== HEALTH CHECK ====================

app.get('/', (req, res) => {
  res.json({
    message: 'Urb Park API',
    version: '1.0.0',
    status: 'running'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ==================== ERROR HANDLING ====================

app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ==================== START SERVER ====================

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n========================================`);
  console.log(`🚀 Urb Park API Server`);
  console.log(`========================================`);
  console.log(`🌐 Local:    http://localhost:${PORT}`);
  console.log(`🌐 Network:  http://192.168.137.1:${PORT}`);
  console.log(`========================================\n`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});
