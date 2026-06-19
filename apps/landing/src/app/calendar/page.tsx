'use client';

import { useState } from 'react';
import { ChevronLeft, ChevronRight, Clock, MapPin, Users } from 'lucide-react';

interface TimeSlot {
  time: string;
  bookings: Array<{
    id: string;
    clientName: string;
    duration: number;
    service: string;
    barber: string;
  }>;
}

export default function CalendarPage() {
  const [selectedDate, setSelectedDate] = useState(new Date('2026-06-19'));
  const [selectedBarber, setSelectedBarber] = useState('all');
  const [viewType] = useState('day');

  const barbers = [
    { id: 'all', name: 'All Barbers', color: 'bg-gray-100' },
    { id: 'barber1', name: 'Ahmed', color: 'bg-blue-100' },
    { id: 'barber2', name: 'Mohammed', color: 'bg-green-100' },
    { id: 'barber3', name: 'Hassan', color: 'bg-purple-100' }
  ];

  const timeSlots: TimeSlot[] = Array.from({ length: 10 }, (_, i) => ({
    time: `${String(9 + i).padStart(2, '0')}:00`,
    bookings: []
  }));

  timeSlots[0].bookings = [
    {
      id: '1',
      clientName: 'Ali Mohammed',
      duration: 30,
      service: 'Haircut',
      barber: 'Ahmed'
    }
  ];

  timeSlots[2].bookings = [
    {
      id: '2',
      clientName: 'Fatima Ali',
      duration: 45,
      service: 'Haircut + Beard',
      barber: 'Mohammed'
    }
  ];

  timeSlots[5].bookings = [
    {
      id: '3',
      clientName: 'Omar Hassan',
      duration: 30,
      service: 'Haircut',
      barber: 'Hassan'
    }
  ];

  const goToPreviousDay = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() - 1);
    setSelectedDate(newDate);
  };

  const goToNextDay = () => {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() + 1);
    setSelectedDate(newDate);
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      year: 'numeric'
    });
  };

  const getBarberColor = (barberId: string) => {
    return barbers.find((b) => b.id === barberId)?.color || 'bg-gray-100';
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="mx-auto max-w-7xl">
        {/* Header */}
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-bold text-gray-900">Booking Calendar</h1>
            <p className="mt-2 text-gray-600">Manage your appointments</p>
          </div>
          <div className="flex gap-4">
            <button className="rounded-lg bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow hover:bg-gray-50">
              Today
            </button>
            <button className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-blue-700">
              New Booking
            </button>
          </div>
        </div>

        <div className="grid gap-6 lg:grid-cols-4">
          {/* Sidebar */}
          <div className="lg:col-span-1">
            {/* Location Info */}
            <div className="mb-6 rounded-lg bg-white p-4 shadow">
              <div className="mb-4 flex items-start gap-3">
                <MapPin className="mt-1 h-5 w-5 text-blue-600" />
                <div>
                  <h3 className="font-semibold text-gray-900">Location</h3>
                  <p className="text-sm text-gray-600">Downtown Shop</p>
                  <p className="text-xs text-gray-500">ID: 3111559</p>
                </div>
              </div>
            </div>

            {/* Barber Filter */}
            <div className="rounded-lg bg-white p-4 shadow">
              <h3 className="mb-4 flex items-center gap-2 font-semibold text-gray-900">
                <Users className="h-5 w-5" />
                Barbers
              </h3>
              <div className="space-y-2">
                {barbers.map((barber) => (
                  <button
                    key={barber.id}
                    onClick={() => setSelectedBarber(barber.id)}
                    className={`w-full rounded-lg px-3 py-2 text-left text-sm font-medium transition ${
                      selectedBarber === barber.id
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
                    }`}
                  >
                    {barber.name}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Calendar */}
          <div className="lg:col-span-3">
            {/* Date Navigation */}
            <div className="mb-6 flex items-center justify-between rounded-lg bg-white p-4 shadow">
              <button
                onClick={goToPreviousDay}
                className="rounded-lg hover:bg-gray-100 p-2"
              >
                <ChevronLeft className="h-6 w-6" />
              </button>
              <div className="text-center">
                <h2 className="text-xl font-bold text-gray-900">
                  {formatDate(selectedDate)}
                </h2>
                <p className="text-sm text-gray-600">{viewType === 'day' && 'Day View'}</p>
              </div>
              <button
                onClick={goToNextDay}
                className="rounded-lg hover:bg-gray-100 p-2"
              >
                <ChevronRight className="h-6 w-6" />
              </button>
            </div>

            {/* Time Slots */}
            <div className="rounded-lg bg-white shadow">
              <div className="space-y-0 divide-y">
                {timeSlots.map((slot, index) => (
                  <div key={index} className="flex">
                    {/* Time Column */}
                    <div className="w-20 flex-shrink-0 border-r bg-gray-50 p-4">
                      <div className="flex items-center gap-1 text-sm font-medium text-gray-600">
                        <Clock className="h-4 w-4" />
                        {slot.time}
                      </div>
                    </div>

                    {/* Booking Slots */}
                    <div className="flex-1 p-4">
                      <div className="space-y-2">
                        {slot.bookings.length > 0 ? (
                          slot.bookings.map((booking) => (
                            <div
                              key={booking.id}
                              className={`rounded-lg p-3 text-sm ${getBarberColor(
                                booking.barber
                              )} border-l-4 border-blue-600 bg-opacity-50`}
                            >
                              <div className="flex items-start justify-between">
                                <div>
                                  <p className="font-semibold text-gray-900">
                                    {booking.clientName}
                                  </p>
                                  <p className="text-xs text-gray-600">
                                    {booking.service}
                                  </p>
                                  <p className="text-xs text-gray-500">
                                    {booking.barber} • {booking.duration} min
                                  </p>
                                </div>
                                <button className="rounded bg-white px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-100">
                                  Edit
                                </button>
                              </div>
                            </div>
                          ))
                        ) : (
                          <div className="text-xs text-gray-400">Available</div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Stats */}
            <div className="mt-6 grid grid-cols-3 gap-4">
              <div className="rounded-lg bg-white p-4 shadow">
                <p className="text-sm text-gray-600">Total Bookings</p>
                <p className="text-2xl font-bold text-gray-900">3</p>
              </div>
              <div className="rounded-lg bg-white p-4 shadow">
                <p className="text-sm text-gray-600">Available Slots</p>
                <p className="text-2xl font-bold text-green-600">7</p>
              </div>
              <div className="rounded-lg bg-white p-4 shadow">
                <p className="text-sm text-gray-600">Occupancy</p>
                <p className="text-2xl font-bold text-blue-600">30%</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
