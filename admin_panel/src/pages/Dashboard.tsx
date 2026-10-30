import { useEffect, useState } from 'react';
import { Users, UserCheck, MessageSquare, BookOpen, Activity, ArrowUpRight } from 'lucide-react';
import api from '../api/axios';
import { wsService } from '../services/websocket';

interface DashboardStats {
  total_users: number;
  online_users: number;
  new_users_today: number;
  total_messages: number;
  total_lessons: number;
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    total_users: 0,
    online_users: 0,
    new_users_today: 0,
    total_messages: 0,
    total_lessons: 0
  });
  const [loading, setLoading] = useState(true);

  const fetchStats = async () => {
    try {
      const res = await api.get('api/admin/dashboard.php');
      setStats(res.data.data.stats);
    } catch (e) {
      console.error('Failed to fetch stats', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  useEffect(() => {
    const unsubRegistered = wsService.on('user_registered', () => {
      setStats(prev => ({ ...prev, total_users: prev.total_users + 1, new_users_today: prev.new_users_today + 1 }));
    });

    const unsubLesson = wsService.on('lesson_added', () => {
      setStats(prev => ({ ...prev, total_lessons: prev.total_lessons + 1 }));
    });

    const unsubMsg = wsService.on('new_message', () => {
      setStats(prev => ({ ...prev, total_messages: prev.total_messages + 1 }));
    });

    const unsubPresence = wsService.on('user_status_changed', () => {
      fetchStats();
    });

    const unsubReconnected = wsService.on('reconnected', () => {
      fetchStats();
    });

    return () => {
      unsubRegistered();
      unsubLesson();
      unsubMsg();
      unsubPresence();
      unsubReconnected();
    };
  }, []);

  if (loading) {
    return (
      <div className="p-8 space-y-6">
        <h1 className="text-2xl font-bold text-slate-800">Dashboard</h1>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="bg-white rounded-2xl p-6 border border-slate-100 shadow-sm animate-pulse h-32" />
          ))}
        </div>
      </div>
    );
  }

  const statCards = [
    { label: 'Total Users', value: stats.total_users, icon: Users, color: 'text-indigo-600', bg: 'bg-indigo-50' },
    { label: 'Online Users', value: stats.online_users, icon: UserCheck, color: 'text-emerald-600', bg: 'bg-emerald-50' },
    { label: 'New Today', value: stats.new_users_today, icon: Activity, color: 'text-blue-600', bg: 'bg-blue-50' },
    { label: 'Total Lessons', value: stats.total_lessons, icon: BookOpen, color: 'text-purple-600', bg: 'bg-purple-50' },
    { label: 'Messages Sent', value: stats.total_messages, icon: MessageSquare, color: 'text-amber-600', bg: 'bg-amber-50' },
  ];

  return (
    <div className="p-4 sm:p-8 space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">Overview</h1>
        <p className="text-slate-500 mt-1">Real-time statistics for WordRise platform.</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        {statCards.map((card, i) => (
          <div key={i} className="bg-white rounded-2xl p-6 border border-slate-200/60 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden group">
            <div className="flex justify-between items-start relative z-10">
              <div>
                <p className="text-sm font-medium text-slate-500">{card.label}</p>
                <h3 className="text-3xl font-bold text-slate-800 mt-2">{card.value.toLocaleString()}</h3>
              </div>
              <div className={`p-3 rounded-xl ${card.bg} transition-colors group-hover:bg-opacity-80`}>
                <card.icon className={`w-6 h-6 ${card.color}`} />
              </div>
            </div>
            
            {card.label === 'Online Users' && stats.online_users > 0 && (
              <div className="absolute bottom-0 left-0 right-0 h-1 bg-emerald-500" />
            )}
          </div>
        ))}
      </div>

      {/* Placeholder for charts or activity feed */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="bg-white rounded-2xl p-6 border border-slate-200/60 shadow-sm lg:col-span-2">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-lg font-semibold text-slate-800">Recent Activity</h2>
            <button className="text-sm text-indigo-600 font-medium hover:text-indigo-700 flex items-center gap-1">
              View all <ArrowUpRight size={16} />
            </button>
          </div>
          <div className="flex flex-col items-center justify-center h-48 text-slate-400">
            <Activity className="w-12 h-12 mb-3 text-slate-200" />
            <p>Activity log visualization will appear here</p>
          </div>
        </div>

        <div className="bg-white rounded-2xl p-6 border border-slate-200/60 shadow-sm">
          <h2 className="text-lg font-semibold text-slate-800 mb-6">System Status</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-slate-600">WebSocket Server</span>
              <span className="flex items-center gap-2 text-sm font-medium text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full">
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                Connected
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-slate-600">REST API</span>
              <span className="flex items-center gap-2 text-sm font-medium text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full">
                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                Operational
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-slate-600">Database</span>
              <span className="flex items-center gap-2 text-sm font-medium text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full">
                <span className="w-2 h-2 rounded-full bg-emerald-500" />
                Operational
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
