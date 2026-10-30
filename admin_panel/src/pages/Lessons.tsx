import { useEffect, useState } from 'react';
import { Search, Trash2, ChevronLeft, ChevronRight, Loader2, BookOpen } from 'lucide-react';
import api from '../api/axios';
import { wsService } from '../services/websocket';

interface Lesson {
  id: number;
  title: string;
  category: string;
  is_public: number;
  import_count: number;
  created_at: string;
  author_name: string;
  author_email: string;
  author_avatar: string | null;
  words_count: number;
}

export default function Lessons() {
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalLessons, setTotalLessons] = useState(0);

  const fetchLessons = async (p = 1, q = search) => {
    setLoading(true);
    try {
      const res = await api.get(`api/admin/lessons/index.php?page=${p}&limit=15&q=${q}`);
      setLessons(res.data.data.lessons);
      setPage(res.data.data.pagination.page);
      setTotalPages(res.data.data.pagination.total_pages);
      setTotalLessons(res.data.data.pagination.total);
    } catch (e) {
      console.error('Failed to fetch lessons', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLessons(1, search);
  }, [search]);

  useEffect(() => {
    const unsubAdded = wsService.on('lesson_added', (lesson: any) => {
      setLessons(prev => {
        if (prev.some(l => l.id === lesson.id)) return prev;
        return [lesson, ...prev];
      });
      setTotalLessons(prev => prev + 1);
    });

    const unsubDeleted = wsService.on('lesson_deleted', (data: any) => {
      setLessons(prev => prev.filter(l => l.id !== data.lesson_id));
      setTotalLessons(prev => Math.max(0, prev - 1));
    });

    const unsubUpdated = wsService.on('lesson_updated', (updatedLesson: any) => {
      setLessons(prev => prev.map(l => l.id === updatedLesson.id ? { ...l, ...updatedLesson } : l));
    });

    const unsubReconnected = wsService.on('reconnected', () => {
      fetchLessons(page, search);
    });

    return () => {
      unsubAdded();
      unsubDeleted();
      unsubUpdated();
      unsubReconnected();
    };
  }, [page, search]);

  const handleDelete = async (lessonId: number) => {
    if (!window.confirm("Are you sure you want to delete this lesson? This action cannot be undone.")) return;
    
    try {
      await api.post('api/admin/lessons/delete.php', { lesson_id: lessonId });
      setLessons(prev => prev.filter(l => l.id !== lessonId));
      setTotalLessons(prev => prev - 1);
    } catch (e: any) {
      alert(e.response?.data?.message || 'Failed to delete lesson');
    }
  };

  return (
    <div className="p-4 sm:p-8 flex flex-col h-full max-h-full">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6 shrink-0">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Lessons</h1>
          <p className="text-sm text-slate-500 mt-1">Manage {totalLessons} lessons across the platform</p>
        </div>
        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
          <input 
            type="text" 
            placeholder="Search lessons or authors..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 transition-all shadow-sm"
          />
        </div>
      </div>

      <div className="flex-1 bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-sm flex flex-col min-h-0">
        <div className="overflow-x-auto flex-1">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/80 border-b border-slate-200">
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider sticky top-0 bg-slate-50/80 backdrop-blur-sm z-10">Lesson</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider sticky top-0 bg-slate-50/80 backdrop-blur-sm z-10">Author</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider sticky top-0 bg-slate-50/80 backdrop-blur-sm z-10">Stats</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider sticky top-0 bg-slate-50/80 backdrop-blur-sm z-10">Status</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right sticky top-0 bg-slate-50/80 backdrop-blur-sm z-10">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center">
                    <Loader2 className="animate-spin mx-auto text-indigo-500 mb-2" size={24} />
                    <p className="text-sm text-slate-500">Loading lessons...</p>
                  </td>
                </tr>
              ) : lessons.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center">
                    <BookOpen className="mx-auto text-slate-300 mb-2" size={32} />
                    <p className="text-slate-500">No lessons found</p>
                  </td>
                </tr>
              ) : (
                lessons.map(lesson => (
                  <tr key={lesson.id} className="hover:bg-slate-50/50 transition-colors group">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex flex-col">
                        <span className="font-medium text-slate-800">{lesson.title}</span>
                        <span className="text-xs text-slate-500">{lesson.category}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <img 
                          src={lesson.author_avatar || `https://ui-avatars.com/api/?name=${lesson.author_name}&background=6366f1&color=fff`} 
                          alt="" 
                          className="w-8 h-8 rounded-full bg-slate-100 object-cover"
                        />
                        <div className="flex flex-col">
                          <span className="text-sm font-medium text-slate-800">{lesson.author_name || 'System'}</span>
                          <span className="text-xs text-slate-500">{lesson.author_email || 'N/A'}</span>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex flex-col">
                        <span className="text-sm text-slate-700">{lesson.words_count} Words</span>
                        <span className="text-xs text-slate-500">{lesson.import_count} Imports</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium border ${
                        lesson.is_public 
                          ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                          : 'bg-slate-50 text-slate-600 border-slate-200'
                      }`}>
                        {lesson.is_public ? 'Public' : 'Private'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      <button 
                        onClick={() => handleDelete(lesson.id)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors" 
                        title="Delete Lesson"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        
        {/* Pagination */}
        <div className="border-t border-slate-100 px-6 py-4 flex items-center justify-between shrink-0 bg-slate-50/50">
          <p className="text-sm text-slate-500">
            Showing <span className="font-medium text-slate-800">{lessons.length > 0 ? (page - 1) * 15 + 1 : 0}</span> to <span className="font-medium text-slate-800">{Math.min(page * 15, totalLessons)}</span> of <span className="font-medium text-slate-800">{totalLessons}</span> lessons
          </p>
          <div className="flex gap-2">
            <button 
              onClick={() => fetchLessons(page - 1)}
              disabled={page === 1}
              className="p-2 border border-slate-200 rounded-lg hover:bg-white disabled:opacity-50 disabled:hover:bg-transparent transition-colors"
            >
              <ChevronLeft size={16} />
            </button>
            <button 
              onClick={() => fetchLessons(page + 1)}
              disabled={page >= totalPages}
              className="p-2 border border-slate-200 rounded-lg hover:bg-white disabled:opacity-50 disabled:hover:bg-transparent transition-colors"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
