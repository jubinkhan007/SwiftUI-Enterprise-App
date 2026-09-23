import React, { useEffect, useState } from 'react';
import { OrgInviteDTO, OrgJoinRequestDTO, OrgMemberDTO } from '../types';
import { api } from '../services/api';
import { 
  Users, 
  UserPlus, 
  Mail, 
  Shield, 
  ShieldAlert, 
  ShieldCheck, 
  Clock, 
  Check, 
  X, 
  Trash2, 
  Copy, 
  CheckCircle2, 
  RefreshCw,
  MoreVertical,
  Edit2
} from 'lucide-react';

export const TeamScreen: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'members' | 'invites' | 'requests'>('members');
  const [members, setMembers] = useState<OrgMemberDTO[]>([]);
  const [invites, setInvites] = useState<OrgInviteDTO[]>([]);
  const [requests, setRequests] = useState<OrgJoinRequestDTO[]>([]);
  const [loading, setLoading] = useState(true);

  // Modals
  const [showInviteModal, setShowInviteModal] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState('member');
  const [inviteSending, setInviteSending] = useState(false);

  const [roleEditMember, setRoleEditMember] = useState<OrgMemberDTO | null>(null);
  const [selectedNewRole, setSelectedNewRole] = useState('member');
  const [roleUpdating, setRoleUpdating] = useState(false);

  const [memberToRemove, setMemberToRemove] = useState<OrgMemberDTO | null>(null);

  const [copiedInviteId, setCopiedInviteId] = useState<string | null>(null);

  const fetchData = async () => {
    setLoading(true);
    try {
      const [membersData, invitesData, requestsData] = await Promise.all([
        api.getOrgMembers().catch(() => []),
        api.getInvites().catch(() => []),
        api.getJoinRequests().catch(() => [])
      ]);
      setMembers(membersData);
      setInvites(invitesData);
      setRequests(requestsData);
    } catch (err) {
      console.error('Failed to load team data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleSendInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inviteEmail.trim()) return;
    setInviteSending(true);
    try {
      const newInvite = await api.createInvite(inviteEmail.trim(), inviteRole);
      setInvites(prev => [newInvite, ...prev]);
      setShowInviteModal(false);
      setInviteEmail('');
      setInviteRole('member');
    } catch (err: any) {
      alert(`Failed to send invite: ${err.message}`);
    } finally {
      setInviteSending(false);
    }
  };

  const handleRevokeInvite = async (inviteId: string) => {
    try {
      await api.revokeInvite(inviteId);
      setInvites(prev => prev.filter(i => i.id !== inviteId));
    } catch (err: any) {
      alert(`Failed to revoke invite: ${err.message}`);
    }
  };

  const handleAcceptRequest = async (requestId: string) => {
    try {
      await api.acceptJoinRequest(requestId);
      setRequests(prev => prev.filter(r => r.id !== requestId));
      await fetchData();
    } catch (err: any) {
      alert(`Failed to accept join request: ${err.message}`);
    }
  };

  const handleRejectRequest = async (requestId: string) => {
    try {
      await api.rejectJoinRequest(requestId);
      setRequests(prev => prev.filter(r => r.id !== requestId));
    } catch (err: any) {
      alert(`Failed to reject join request: ${err.message}`);
    }
  };

  const handleUpdateRole = async () => {
    if (!roleEditMember) return;
    setRoleUpdating(true);
    try {
      await api.updateMemberRole(roleEditMember.id, selectedNewRole);
      setMembers(prev => prev.map(m => m.id === roleEditMember.id ? { ...m, role: selectedNewRole } : m));
      setRoleEditMember(null);
    } catch (err: any) {
      alert(`Failed to update role: ${err.message}`);
    } finally {
      setRoleUpdating(false);
    }
  };

  const handleRemoveMember = async () => {
    if (!memberToRemove) return;
    try {
      await api.removeMember(memberToRemove.id);
      setMembers(prev => prev.filter(m => m.id !== memberToRemove.id));
      setMemberToRemove(null);
    } catch (err: any) {
      alert(`Failed to remove member: ${err.message}`);
    }
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedInviteId(id);
    setTimeout(() => setCopiedInviteId(null), 2000);
  };

  const getRoleBadge = (role: string) => {
    switch (role.toLowerCase()) {
      case 'owner':
        return (
          <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-purple-500/20 text-purple-300 border border-purple-500/30 flex items-center gap-1">
            <ShieldCheck className="w-3 h-3" /> Owner
          </span>
        );
      case 'admin':
        return (
          <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-blue-500/20 text-blue-300 border border-blue-500/30 flex items-center gap-1">
            <Shield className="w-3 h-3" /> Admin
          </span>
        );
      case 'manager':
        return (
          <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30 flex items-center gap-1">
            Manager
          </span>
        );
      case 'guest':
        return (
          <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-500/20 text-slate-300 border border-slate-500/30">
            Guest
          </span>
        );
      default:
        return (
          <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-700 text-slate-200 border border-slate-600">
            Member
          </span>
        );
    }
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4 shrink-0">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <Users className="w-6 h-6 text-indigo-400" />
            Team & Organization
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Manage organization members, pending invitations, and workspace join requests
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowInviteModal(true)}
            className="px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition flex items-center gap-2 text-xs font-semibold shadow-lg shadow-indigo-600/30 cursor-pointer"
          >
            <UserPlus className="w-4 h-4" />
            Invite Member
          </button>
        </div>
      </div>

      {/* Segmented 3-Tab Selector */}
      <div className="px-6 pt-4 pb-2 border-b border-slate-800 flex items-center gap-3 shrink-0 bg-slate-900/30">
        <button
          onClick={() => setActiveTab('members')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
            activeTab === 'members'
              ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
          }`}
        >
          <Users className="w-4 h-4" />
          <span>Members</span>
          <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-slate-800 text-slate-300 font-mono">
            {members.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('invites')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
            activeTab === 'invites'
              ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
          }`}
        >
          <Mail className="w-4 h-4" />
          <span>Invites</span>
          <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-slate-800 text-slate-300 font-mono">
            {invites.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('requests')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
            activeTab === 'requests'
              ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
          }`}
        >
          <Clock className="w-4 h-4" />
          <span>Requests</span>
          {requests.length > 0 && (
            <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-amber-500/20 text-amber-300 font-mono font-bold">
              {requests.length}
            </span>
          )}
        </button>
      </div>

      {/* Main Tab Content */}
      <div className="flex-1 overflow-y-auto p-6">
        {loading ? (
          <div className="flex items-center justify-center h-64 text-slate-400 gap-3">
            <RefreshCw className="w-6 h-6 animate-spin text-indigo-400" />
            <span>Loading organization data...</span>
          </div>
        ) : (
          <>
            {/* TAB 1: MEMBERS */}
            {activeTab === 'members' && (
              <div className="space-y-3 max-w-4xl">
                {members.length === 0 ? (
                  <div className="p-12 text-center text-slate-500 border border-dashed border-slate-800 rounded-2xl">
                    No members found.
                  </div>
                ) : (
                  members.map(member => (
                    <div
                      key={member.id}
                      className="bg-slate-900/60 border border-slate-800 hover:border-slate-700/80 rounded-2xl p-4 flex items-center justify-between transition group"
                    >
                      <div className="flex items-center gap-3.5">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-600 to-teal-500 flex items-center justify-center text-xs font-bold text-white shadow-md">
                          {(member.displayName || member.email).slice(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-bold text-slate-200">
                              {member.displayName || 'Team Member'}
                            </span>
                            {getRoleBadge(member.role)}
                          </div>
                          <span className="text-xs text-slate-400 font-mono">
                            {member.email}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => {
                            setRoleEditMember(member);
                            setSelectedNewRole(member.role);
                          }}
                          className="px-3 py-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 text-xs font-semibold flex items-center gap-1.5 border border-slate-700/60 transition cursor-pointer"
                          title="Change Role"
                        >
                          <Edit2 className="w-3.5 h-3.5 text-indigo-400" />
                          Role
                        </button>
                        <button
                          onClick={() => setMemberToRemove(member)}
                          className="p-2 rounded-xl text-slate-500 hover:text-red-400 hover:bg-red-500/10 transition cursor-pointer"
                          title="Remove Member"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* TAB 2: INVITES */}
            {activeTab === 'invites' && (
              <div className="space-y-3 max-w-4xl">
                {invites.length === 0 ? (
                  <div className="p-12 text-center text-slate-500 border border-dashed border-slate-800 rounded-2xl">
                    No pending invitations. Click "Invite Member" to add colleagues.
                  </div>
                ) : (
                  invites.map(invite => (
                    <div
                      key={invite.id}
                      className="bg-slate-900/60 border border-slate-800 hover:border-slate-700/80 rounded-2xl p-4 flex items-center justify-between transition"
                    >
                      <div className="flex items-center gap-3.5">
                        <div className="w-10 h-10 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-slate-400">
                          <Mail className="w-4 h-4" />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-bold text-slate-200">
                              {invite.email}
                            </span>
                            {getRoleBadge(invite.role)}
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                              {invite.status.toUpperCase()}
                            </span>
                          </div>
                          <span className="text-xs text-slate-500">
                            Expires: {invite.expiresAt ? new Date(invite.expiresAt).toLocaleDateString() : '30 days'}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => copyToClipboard(invite.id, invite.id)}
                          className="px-3 py-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 text-xs font-semibold flex items-center gap-1.5 border border-slate-700/60 transition cursor-pointer"
                          title="Copy Invite ID"
                        >
                          {copiedInviteId === invite.id ? (
                            <>
                              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
                              Copied
                            </>
                          ) : (
                            <>
                              <Copy className="w-3.5 h-3.5 text-slate-400" />
                              Copy ID
                            </>
                          )}
                        </button>
                        <button
                          onClick={() => handleRevokeInvite(invite.id)}
                          className="px-3 py-1.5 rounded-xl text-red-400 hover:bg-red-500/10 border border-red-500/20 text-xs font-semibold transition cursor-pointer"
                        >
                          Revoke
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* TAB 3: JOIN REQUESTS */}
            {activeTab === 'requests' && (
              <div className="space-y-3 max-w-4xl">
                {requests.length === 0 ? (
                  <div className="p-12 text-center text-slate-500 border border-dashed border-slate-800 rounded-2xl">
                    No pending join requests.
                  </div>
                ) : (
                  requests.map(req => (
                    <div
                      key={req.id}
                      className="bg-slate-900/60 border border-slate-800 hover:border-slate-700/80 rounded-2xl p-4 flex items-center justify-between transition"
                    >
                      <div className="flex items-center gap-3.5">
                        <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-amber-600 to-indigo-600 flex items-center justify-center text-xs font-bold text-white shadow-md">
                          {(req.userDisplayName || req.userEmail || 'U').slice(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-bold text-slate-200">
                              {req.userDisplayName || 'Applicant'}
                            </span>
                            <span className="text-xs text-slate-400 font-mono">
                              ({req.userEmail || 'no email'})
                            </span>
                          </div>
                          {req.message && (
                            <p className="text-xs text-slate-400 mt-0.5">"{req.message}"</p>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => handleAcceptRequest(req.id)}
                          className="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold flex items-center gap-1.5 shadow-md shadow-emerald-600/20 transition cursor-pointer"
                        >
                          <Check className="w-3.5 h-3.5" />
                          Accept
                        </button>
                        <button
                          onClick={() => handleRejectRequest(req.id)}
                          className="px-3.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-red-400 text-xs font-semibold flex items-center gap-1.5 border border-slate-700 transition cursor-pointer"
                        >
                          <X className="w-3.5 h-3.5" />
                          Reject
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}
          </>
        )}
      </div>

      {/* MODAL 1: INVITE MEMBER */}
      {showInviteModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <form onSubmit={handleSendInvite} className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <UserPlus className="w-5 h-5 text-indigo-400" />
                Invite Team Member
              </h2>
              <button
                type="button"
                onClick={() => setShowInviteModal(false)}
                className="p-1 text-slate-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Email Address
                </label>
                <input
                  type="email"
                  required
                  placeholder="colleague@example.com"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Role
                </label>
                <div className="grid grid-cols-4 gap-2 mt-1">
                  {['guest', 'member', 'manager', 'admin'].map(r => (
                    <button
                      key={r}
                      type="button"
                      onClick={() => setInviteRole(r)}
                      className={`py-2 rounded-xl text-xs font-bold capitalize transition border cursor-pointer ${
                        inviteRole === r
                          ? 'bg-indigo-600 text-white border-indigo-500 shadow-md'
                          : 'bg-slate-950 text-slate-400 border-slate-800 hover:bg-slate-800'
                      }`}
                    >
                      {r}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setShowInviteModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-slate-200 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={inviteSending || !inviteEmail.trim()}
                className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition shadow-lg shadow-indigo-600/30 disabled:opacity-50 cursor-pointer"
              >
                {inviteSending ? 'Sending...' : 'Send Invitation'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* MODAL 2: EDIT ROLE */}
      {roleEditMember && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-sm shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Shield className="w-5 h-5 text-indigo-400" />
                Change Role
              </h2>
              <button
                onClick={() => setRoleEditMember(null)}
                className="p-1 text-slate-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-xs text-slate-400">
              Update organization role for <span className="text-slate-200 font-semibold">{roleEditMember.displayName || roleEditMember.email}</span>.
            </p>

            <div className="space-y-2">
              {[
                { role: 'admin', label: 'Admin', desc: 'Full workspace and team management' },
                { role: 'manager', label: 'Manager', desc: 'Can manage tasks, projects, and meetings' },
                { role: 'member', label: 'Member', desc: 'Standard collaborative access' },
                { role: 'guest', label: 'Guest', desc: 'Read-only and limited channel access' },
              ].map(item => (
                <div
                  key={item.role}
                  onClick={() => setSelectedNewRole(item.role)}
                  className={`p-3 rounded-xl border cursor-pointer transition flex items-center justify-between ${
                    selectedNewRole === item.role
                      ? 'bg-indigo-600/20 border-indigo-500 text-indigo-300'
                      : 'bg-slate-950 border-slate-800 text-slate-300 hover:bg-slate-800/50'
                  }`}
                >
                  <div>
                    <span className="text-xs font-bold block">{item.label}</span>
                    <span className="text-[11px] text-slate-400">{item.desc}</span>
                  </div>
                  {selectedNewRole === item.role && (
                    <CheckCircle2 className="w-4 h-4 text-indigo-400 shrink-0" />
                  )}
                </div>
              ))}
            </div>

            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                onClick={() => setRoleEditMember(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-slate-200 cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleUpdateRole}
                disabled={roleUpdating}
                className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition shadow-lg shadow-indigo-600/30 cursor-pointer"
              >
                {roleUpdating ? 'Saving...' : 'Update Role'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: REMOVE CONFIRMATION */}
      {memberToRemove && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-sm shadow-2xl space-y-4">
            <h2 className="text-base font-bold text-red-400 flex items-center gap-2">
              <Trash2 className="w-5 h-5" />
              Remove Member?
            </h2>
            <p className="text-xs text-slate-300 leading-relaxed">
              Are you sure you want to remove <span className="font-semibold text-white">{memberToRemove.displayName || memberToRemove.email}</span> from this workspace? They will lose access to all channels and tasks.
            </p>
            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                onClick={() => setMemberToRemove(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-slate-200 cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleRemoveMember}
                className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white text-xs font-bold transition cursor-pointer"
              >
                Remove
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
