import React, { useState, useEffect } from 'react';
import { 
  LayoutDashboard, 
  User, 
  Mail, 
  MessageSquare, 
  Calendar, 
  Zap, 
  ShieldCheck, 
  Building2, 
  CheckCircle2, 
  ChevronDown, 
  ChevronRight, 
  Folder, 
  List,
  LogOut,
  Plus,
  Users,
  X,
  CreditCard
} from 'lucide-react';
import { HierarchyTreeDTO, NavDestination, UserDTO } from '../types';
import { api } from '../services/api';
import { WorkspaceSwitcherModal } from './WorkspaceSwitcherModal';

export interface SidebarDrawerProps {
  isOpen?: boolean;
  onClose?: () => void;
  currentNav?: NavDestination;
  onNavigate?: (dest: NavDestination) => void;
  selectedDestination?: NavDestination;
  onSelectDestination?: (dest: NavDestination) => void;
  hierarchy?: HierarchyTreeDTO | null;
  currentUser: UserDTO | null;
  onLogout: () => void;
}

export const SidebarDrawer: React.FC<SidebarDrawerProps> = ({
  isOpen = true,
  onClose = () => {},
  currentNav,
  onNavigate,
  selectedDestination,
  onSelectDestination,
  hierarchy: propHierarchy,
  currentUser,
  onLogout,
}) => {
  const [hierarchy, setHierarchy] = useState<HierarchyTreeDTO | null>(propHierarchy || null);
  const [expandedSpaces, setExpandedSpaces] = useState<Record<string, boolean>>({
    engineering: true
  });

  // Modal state for Space / Project / TaskList creation
  const [showCreateSpaceModal, setShowCreateSpaceModal] = useState(false);
  const [createSpaceName, setCreateSpaceName] = useState('');
  const [createSpaceDesc, setCreateSpaceDesc] = useState('');

  const [showCreateProjectModal, setShowCreateProjectModal] = useState<string | null>(null); // spaceId
  const [createProjectName, setCreateProjectName] = useState('');

  const [showCreateListModal, setShowCreateListModal] = useState<string | null>(null); // projectId
  const [createListName, setCreateListName] = useState('');

  const [showWorkspaceSwitcher, setShowWorkspaceSwitcher] = useState(false);

  const refreshHierarchy = async () => {
    try {
      const data = await api.getHierarchy();
      setHierarchy(data);
    } catch (err) {
      console.error('Failed to refresh hierarchy:', err);
    }
  };

  const handleCreateSpaceSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createSpaceName.trim()) return;
    try {
      await api.createSpace(createSpaceName.trim(), createSpaceDesc.trim() || undefined);
      setShowCreateSpaceModal(false);
      setCreateSpaceName('');
      setCreateSpaceDesc('');
      await refreshHierarchy();
    } catch (err: any) {
      alert(`Failed to create Space: ${err.message || err}`);
    }
  };

  const handleCreateProjectSubmit = async (e: React.FormEvent, spaceId: string) => {
    e.preventDefault();
    if (!createProjectName.trim()) return;
    try {
      await api.createProject(spaceId, createProjectName.trim());
      setShowCreateProjectModal(null);
      setCreateProjectName('');
      await refreshHierarchy();
    } catch (err: any) {
      alert(`Failed to create Project: ${err.message || err}`);
    }
  };

  const handleCreateListSubmit = async (e: React.FormEvent, projectId: string) => {
    e.preventDefault();
    if (!createListName.trim()) return;
    try {
      await api.createTaskList(projectId, createListName.trim());
      setShowCreateListModal(null);
      setCreateListName('');
      await refreshHierarchy();
    } catch (err: any) {
      alert(`Failed to create Task List: ${err.message || err}`);
    }
  };

  const activeNav = currentNav || selectedDestination || 'all_tasks';

  const handleNavigate = (dest: NavDestination) => {
    if (onNavigate) onNavigate(dest);
    if (onSelectDestination) onSelectDestination(dest);
    onClose();
  };

  useEffect(() => {
    if (!hierarchy) {
      api.getHierarchy()
        .then(res => setHierarchy(res))
        .catch(err => console.error(err));
    }
  }, [hierarchy]);

  const toggleSpace = (spaceId: string) => {
    setExpandedSpaces(prev => ({ ...prev, [spaceId]: !prev[spaceId] }));
  };

  const navItems: { id: NavDestination; label: string; icon: React.FC<{ className?: string }> }[] = [
    { id: 'all_tasks', label: 'All Tasks', icon: LayoutDashboard },
    { id: 'my_tasks', label: 'My Tasks', icon: User },
    { id: 'inbox', label: 'Inbox', icon: Mail },
    { id: 'messages', label: 'Messages & Channels', icon: MessageSquare },
    { id: 'meetings', label: 'Meetings & Time', icon: Calendar },
    { id: 'team', label: 'Team & Organization', icon: Users },
    { id: 'billing', label: 'Billing & Plans', icon: CreditCard },
    { id: 'productivity', label: 'Productivity Hub', icon: Zap },
    { id: 'sessions', label: 'Security Sessions', icon: ShieldCheck },
  ];

  return (
    <>
      {/* Mobile Backdrop */}
      {isOpen && (
        <div 
          onClick={onClose}
          className="fixed inset-0 bg-black/60 backdrop-blur-xs z-40 lg:hidden"
        />
      )}

      {/* Drawer Sidebar */}
      <aside
        className={`w-72 bg-slate-900/90 backdrop-blur-xl border-r border-slate-800/80 h-full flex flex-col shrink-0 z-30 transition-transform duration-300 ease-in-out`}
      >
        {/* Mobile Close Header */}
        <div className="flex items-center justify-between p-4 lg:hidden border-b border-slate-800/50">
          <span className="text-xs font-bold text-slate-400 tracking-wider">NAVIGATION</span>
          <button onClick={onClose} className="p-1 text-slate-400 hover:text-white rounded-lg">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Workspace Banner */}
        <div className="p-4">
          <div 
            onClick={() => setShowWorkspaceSwitcher(true)}
            className="p-3.5 rounded-xl bg-slate-800/50 hover:bg-slate-800/80 border border-slate-700/50 flex items-center justify-between shadow-lg shadow-black/20 cursor-pointer transition group"
            title="Switch Workspace"
          >
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-indigo-600 to-teal-500 flex items-center justify-center shadow-md">
                <Building2 className="w-5 h-5 text-white" />
              </div>
              <div className="flex flex-col">
                <span className="text-sm font-bold text-slate-100 group-hover:text-indigo-300 transition">Acme Corp</span>
                <span className="text-[11px] font-semibold text-teal-400">Pro Tier Workspace</span>
              </div>
            </div>
            <div className="flex items-center gap-1.5">
              <CheckCircle2 className="w-4 h-4 text-teal-400" />
              <ChevronDown className="w-3.5 h-3.5 text-slate-400 group-hover:text-white transition" />
            </div>
          </div>
        </div>

        {/* Navigation List */}
        <div className="flex-1 overflow-y-auto px-4 py-2 space-y-6 scrollbar-thin">
          <div>
            <div className="px-2 mb-2 text-[11px] font-bold text-slate-500 tracking-wider">NAVIGATION</div>
            <div className="space-y-1">
              {navItems.map((item) => {
                const IconComponent = item.icon;
                const isSelected = activeNav === item.id;
                return (
                  <button
                    key={item.id}
                    onClick={() => handleNavigate(item.id)}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-150 cursor-pointer ${
                      isSelected
                        ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-md shadow-indigo-500/10'
                        : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/50'
                    }`}
                  >
                    <IconComponent className={`w-4 h-4 ${isSelected ? 'text-indigo-400' : 'text-slate-400'}`} />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Expandable Hierarchy Disclosure Tree */}
          <div>
            <div className="px-2 mb-2 flex items-center justify-between">
              <span className="text-[11px] font-bold text-slate-500 tracking-wider">WORKSPACES & SPACES</span>
              <button
                onClick={() => setShowCreateSpaceModal(true)}
                className="p-1 rounded text-slate-400 hover:text-indigo-400 hover:bg-slate-800/50 transition cursor-pointer"
                title="Create New Space"
              >
                <Plus className="w-3.5 h-3.5" />
              </button>
            </div>
            <div className="space-y-1">
              {hierarchy?.spaces?.map((spaceNode) => {
                const spaceId = spaceNode.space.id || 'space-node';
                const isExpanded = expandedSpaces[spaceId] ?? true;
                return (
                  <div key={spaceId} className="space-y-1">
                    <div className="flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs font-semibold text-slate-300 hover:bg-slate-800/40 group">
                      <button
                        onClick={() => toggleSpace(spaceId)}
                        className="flex items-center gap-2 truncate text-left flex-1 cursor-pointer"
                      >
                        {isExpanded ? (
                          <ChevronDown className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                        ) : (
                          <ChevronRight className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                        )}
                        <Building2 className="w-3.5 h-3.5 text-indigo-400 shrink-0" />
                        <span className="truncate">{spaceNode.space.name || 'Engineering'}</span>
                      </button>
                      <button
                        onClick={() => setShowCreateProjectModal(spaceId)}
                        className="hidden group-hover:block p-1 rounded hover:bg-slate-700 text-slate-400 hover:text-teal-400 cursor-pointer"
                        title="Add Project to Space"
                      >
                        <Plus className="w-3 h-3" />
                      </button>
                    </div>

                    {isExpanded && (
                      <div className="pl-6 space-y-1">
                        {spaceNode.projects?.map((projNode) => {
                          const projId = projNode.project.id || 'proj-node';
                          return (
                            <div key={projId} className="space-y-1">
                              <div className="flex items-center justify-between px-2 py-1 rounded-md text-xs text-slate-400 hover:bg-slate-800/30 group">
                                <div className="flex items-center gap-2 truncate">
                                  <Folder className="w-3.5 h-3.5 text-teal-400 shrink-0" />
                                  <span className="truncate">{projNode.project.name || 'Project'}</span>
                                </div>
                                <button
                                  onClick={() => setShowCreateListModal(projId)}
                                  className="hidden group-hover:block p-1 rounded hover:bg-slate-700 text-slate-400 hover:text-indigo-400 cursor-pointer"
                                  title="Add Task List to Project"
                                >
                                  <Plus className="w-3 h-3" />
                                </button>
                              </div>

                              {projNode.lists?.map((listNode) => (
                                <div key={listNode.id} className="pl-5 flex items-center gap-2 px-2 py-0.5 text-[11px] text-slate-500 hover:text-slate-300">
                                  <List className="w-3 h-3 text-slate-500" />
                                  <span className="truncate">{listNode.name}</span>
                                </div>
                              ))}
                            </div>
                          );
                        })}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* User Profile Footer */}
        {currentUser && (
          <div className="p-4 border-t border-slate-800/80">
            <div className="p-3 rounded-xl bg-slate-800/40 border border-slate-800/80 flex items-center justify-between">
              <div className="flex flex-col min-w-0 pr-2">
                <span className="text-xs font-bold text-slate-200 truncate">
                  {currentUser.displayName || 'User'}
                </span>
                <span className="text-[11px] text-slate-400 truncate">
                  {currentUser.email || ''}
                </span>
              </div>
              <button
                onClick={onLogout}
                title="Sign Out"
                className="p-1.5 text-rose-400 hover:bg-rose-500/10 rounded-lg transition-colors cursor-pointer"
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </aside>

      {/* Create Space Modal */}
      {showCreateSpaceModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Building2 className="w-5 h-5 text-indigo-400" /> Create New Space
              </h3>
              <button onClick={() => setShowCreateSpaceModal(false)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleCreateSpaceSubmit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Space Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Design Systems"
                  value={createSpaceName}
                  onChange={(e) => setCreateSpaceName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Description (Optional)
                </label>
                <input
                  type="text"
                  placeholder="Description of this space..."
                  value={createSpaceDesc}
                  onChange={(e) => setCreateSpaceDesc(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                />
              </div>
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateSpaceModal(false)}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-600/30"
                >
                  Create Space
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Project Modal */}
      {showCreateProjectModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Folder className="w-5 h-5 text-teal-400" /> Create Project
              </h3>
              <button onClick={() => setShowCreateProjectModal(null)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={(e) => handleCreateProjectSubmit(e, showCreateProjectModal)} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Project Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Mobile Redesign"
                  value={createProjectName}
                  onChange={(e) => setCreateProjectName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateProjectModal(null)}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-teal-600 text-white hover:bg-teal-500 shadow-lg shadow-teal-600/30"
                >
                  Create Project
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Task List Modal */}
      {showCreateListModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <List className="w-5 h-5 text-indigo-400" /> Create Task List
              </h3>
              <button onClick={() => setShowCreateListModal(null)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={(e) => handleCreateListSubmit(e, showCreateListModal)} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  List Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Backlog"
                  value={createListName}
                  onChange={(e) => setCreateListName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateListModal(null)}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-600/30"
                >
                  Create Task List
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
      {/* Workspace Switcher Modal */}
      <WorkspaceSwitcherModal
        isOpen={showWorkspaceSwitcher}
        onClose={() => setShowWorkspaceSwitcher(false)}
      />
    </>
  );
};
