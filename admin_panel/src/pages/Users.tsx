import { useEffect, useState } from 'react';
import { Search, Shield, Trash2, ChevronLeft, ChevronRight, Loader2, Key, Eye, X } from 'lucide-react';
import api from '../api/axios';
import { wsService } from '../services/websocket';

interface User {
  id: number;
  name: string;
  username: string;
  email: string;
  role: string;
  level: number;
  xp: number;
  last_seen_at: string;
  created_at: string;
  avatar: string | null;
}

export default function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalUsers, setTotalUsers] = useState(0);

  // Modal states
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [isPasswordModalOpen, setPasswordModalOpen] = useState(false);
  const [isDetailsModalOpen, setDetailsModalOpen] = useState(false);
  const [newPassword, setNewPassword] = useState('');
  const [passwordLoading, setPasswordLoading] = useState(false);

  const fetchUsers = async (p = 1, q = search) => {
    setLoading(true);
    try {
      const res = await api.get(`api/admin/users/index.php?page=${p}&limit=15&q=${q}`);
      setUsers(res.data.data.users);
      setPage(res.data.data.pagination.page);
      setTotalPages(res.data.data.pagination.total_pages);
      setTotalUsers(res.data.data.pagination.total);
    } catch (e) {
      console.error('Failed to fetch users', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers(page, search);
  }, [page, search]);

  useEffect(() => {
    const unsubRegistered = wsService.on('user_registered', (user: any) => {
      setUsers(prev => {
        if (prev.some(u => u.id === user.id)) return prev;
        return [user, ...prev];
      });
      setTotalUsers(prev => prev + 1);
    });

    const unsubDeleted = wsService.on('user_deleted', (data: any) => {
      setUsers(prev => prev.filter(u => u.id !== data.user_id));
      setTotalUsers(prev => Math.max(0, prev - 1));
    });

    const unsubUpdated = wsService.on('user_updated', (updatedUser: any) => {
      setUsers(prev => prev.map(u => u.id === updatedUser.id ? { ...u, ...updatedUser } : u));
      if (selectedUser?.id === updatedUser.id) {
        setSelectedUser(prev => ({ ...prev, ...updatedUser } as User));
      }
    });

    const unsubRoleChanged = wsService.on('user_role_changed', (data: any) => {
      setUsers(prev => prev.map(u => u.id === data.user_id ? { ...u, role: data.role } : u));
      if (selectedUser?.id === data.user_id) {
        setSelectedUser(prev => ({ ...prev, role: data.role } as User));
      }
    });

    const unsubReconnected = wsService.on('reconnected', () => {
      fetchUsers(page, search);
    });

    return () => {
      unsubRegistered();
      unsubDeleted();
      unsubUpdated();
      unsubRoleChanged();
      unsubReconnected();
    };
  }, [page, search, selectedUser]);

  useEffect(() => {
    const delayDebounceFn = setTimeout(() => {
      fetchUsers(1, search);
    }, 400);

    return () => clearTimeout(delayDebounceFn);
  }, [search]);

  const handleRoleChange = async (userId: number, newRole: string) => {
    if (!window.confirm(`Are you sure you want to change this user's role to ${newRole}?`)) return;
    
    try {
      await api.post('api/admin/users/update_role.php', {
        user_id: userId,
        role: newRole
      });
      // Optimistically update UI
      setUsers(users.map(u => u.id === userId ? { ...u, role: newRole } : u));
    } catch (e: any) {
      alert(e.response?.data?.message || 'Failed to update role');
    }
  };

  const handlePasswordReset = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser || newPassword.length < 6) return;
    
    setPasswordLoading(true);
    try {
      await api.post('api/admin/users/update_password.php', {
        user_id: selectedUser.id,
        password: newPassword
      });
      alert('Password updated successfully!');
      setPasswordModalOpen(false);
      setNewPassword('');
    } catch (e: any) {
      alert(e.response?.data?.message || 'Failed to update password');
    } finally {
      setPasswordLoading(false);
    }
  };

  return (
    <div className="p-4 sm:p-8 flex flex-col h-full max-h-full">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6 shrink-0">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Users Management</h1>
          <p className="text-sm text-slate-500 mt-1">Total {totalUsers.toLocaleString()} users registered</p>
        </div>
        
        <div className="relative w-full sm:w-72">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <Search className="h-4 w-4 text-slate-400" />
          </div>
          <input
            type="text"
            placeholder="Search users by name, email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="block w-full pl-10 pr-3 py-2 border border-slate-200 rounded-xl bg-white text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent text-sm shadow-sm"
          />
        </div>
      </div>

      <div className="bg-white border border-slate-200 rounded-2xl shadow-sm flex-1 flex flex-col min-h-0 overflow-hidden">
        <div className="overflow-x-auto flex-1">
          <table className="w-full text-left text-sm text-slate-600">
            <thead className="bg-slate-50 border-b border-slate-200 text-xs uppercase text-slate-500 font-semibold sticky top-0 z-10">
              <tr>
                <th className="px-6 py-4">User</th>
                <th className="px-6 py-4">Role</th>
                <th className="px-6 py-4">Level / XP</th>
                <th className="px-6 py-4">Joined At</th>
                <th className="px-6 py-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading && users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center">
                    <Loader2 className="w-6 h-6 animate-spin text-indigo-500 mx-auto" />
                    <p className="mt-2 text-slate-500">Loading users...</p>
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center text-slate-500">
                    No users found matching your search.
                  </td>
                </tr>
              ) : (
                users.map((user) => (
                  <tr key={user.id} className="hover:bg-slate-50/50 transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-3">
                        <img 
                          src={user.avatar || `https://ui-avatars.com/api/?name=${user.name}&background=6366f1&color=fff`} 
                          alt="" 
                          className="w-10 h-10 rounded-full object-cover shadow-sm border border-slate-200"
                        />
                        <div>
                          <div className="font-medium text-slate-800">{user.name}</div>
                          <div className="text-xs text-slate-500">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium capitalize border
                        ${user.role === 'admin' ? 'bg-purple-50 text-purple-700 border-purple-200' : 
                          user.role === 'teacher' ? 'bg-blue-50 text-blue-700 border-blue-200' : 
                          'bg-slate-100 text-slate-700 border-slate-200'}
                      `}>
                        {user.role}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-slate-800 font-medium">Lvl {user.level}</div>
                      <div className="text-xs text-slate-500">{user.xp.toLocaleString()} XP</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-slate-500">
                      {new Date(user.created_at).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button 
                          onClick={() => { setSelectedUser(user); setDetailsModalOpen(true); }}
                          className="p-1.5 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                          title="View Details"
                        >
                          <Eye size={16} />
                        </button>
                        <button 
                          onClick={() => { setSelectedUser(user); setPasswordModalOpen(true); }}
                          className="p-1.5 text-slate-400 hover:text-amber-600 hover:bg-amber-50 rounded-lg transition-colors"
                          title="Reset Password"
                        >
                          <Key size={16} />
                        </button>
                        {user.role !== 'admin' && (
                          <button 
                            onClick={() => handleRoleChange(user.id, user.role === 'teacher' ? 'student' : 'teacher')}
                            className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                            title={user.role === 'teacher' ? 'Demote to Student' : 'Promote to Teacher'}
                          >
                            <Shield size={16} />
                          </button>
                        )}
                        <button className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors" title="Delete User">
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="px-6 py-4 border-t border-slate-200 bg-slate-50 flex items-center justify-between shrink-0">
          <div className="text-sm text-slate-500">
            Showing <span className="font-medium text-slate-700">{users.length}</span> of <span className="font-medium text-slate-700">{totalUsers}</span> results
          </div>
          
          <div className="flex items-center gap-2">
            <button
              disabled={page <= 1}
              onClick={() => fetchUsers(page - 1)}
              className="p-1.5 rounded-lg border border-slate-300 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed shadow-sm transition-colors"
            >
              <ChevronLeft size={18} />
            </button>
            <span className="text-sm font-medium text-slate-700 px-2">
              Page {page} of {totalPages}
            </span>
            <button
              disabled={page >= totalPages}
              onClick={() => fetchUsers(page + 1)}
              className="p-1.5 rounded-lg border border-slate-300 bg-white text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed shadow-sm transition-colors"
            >
              <ChevronRight size={18} />
            </button>
          </div>
        </div>
      </div>

      {/* Password Reset Modal */}
      {isPasswordModalOpen && selectedUser && (
        <div className="fixed inset-0 bg-slate-900/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
              <h3 className="font-semibold text-slate-800">Reset Password</h3>
              <button onClick={() => setPasswordModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handlePasswordReset} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">
                  New Password for {selectedUser.name}
                </label>
                <input
                  type="text"
                  required
                  minLength={6}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Enter new password"
                  className="w-full px-3 py-2 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500"
                />
                <p className="text-xs text-slate-500 mt-1.5">Password must be at least 6 characters long.</p>
              </div>
              <div className="pt-2 flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setPasswordModalOpen(false)}
                  className="px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={passwordLoading || newPassword.length < 6}
                  className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-xl disabled:opacity-50 flex items-center gap-2"
                >
                  {passwordLoading && <Loader2 size={16} className="animate-spin" />}
                  Save Password
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Details Modal */}
      {isDetailsModalOpen && selectedUser && (
        <div className="fixed inset-0 bg-slate-900/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
              <h3 className="font-semibold text-slate-800">User Details</h3>
              <button onClick={() => setDetailsModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                <X size={20} />
              </button>
            </div>
            <div className="p-6 space-y-6">
              <div className="flex items-center gap-4">
                <img 
                  src={selectedUser.avatar || `https://ui-avatars.com/api/?name=${selectedUser.name}&background=6366f1&color=fff`}
                  alt=""
                  className="w-16 h-16 rounded-full shadow-sm"
                />
                <div>
                  <h4 className="text-lg font-bold text-slate-800">{selectedUser.name}</h4>
                  <p className="text-sm text-slate-500">@{selectedUser.username} • {selectedUser.email}</p>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                  <p className="text-xs text-slate-500 font-medium uppercase mb-1">Role</p>
                  <p className="text-sm font-semibold text-slate-800 capitalize">{selectedUser.role}</p>
                </div>
                <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                  <p className="text-xs text-slate-500 font-medium uppercase mb-1">Level & XP</p>
                  <p className="text-sm font-semibold text-slate-800">Level {selectedUser.level} ({selectedUser.xp} XP)</p>
                </div>
                <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                  <p className="text-xs text-slate-500 font-medium uppercase mb-1">Joined Date</p>
                  <p className="text-sm font-semibold text-slate-800">{new Date(selectedUser.created_at).toLocaleString()}</p>
                </div>
                <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                  <p className="text-xs text-slate-500 font-medium uppercase mb-1">Last Active</p>
                  <p className="text-sm font-semibold text-slate-800">
                    {selectedUser.last_seen_at ? new Date(selectedUser.last_seen_at).toLocaleString() : 'Never'}
                  </p>
                </div>
              </div>
            </div>
            <div className="px-6 py-4 border-t border-slate-100 bg-slate-50 flex justify-end">
               <button
                  onClick={() => setDetailsModalOpen(false)}
                  className="px-4 py-2 text-sm font-medium text-slate-600 bg-white border border-slate-200 hover:bg-slate-50 rounded-xl"
                >
                  Close
                </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
