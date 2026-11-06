import React, { useEffect, useState } from 'react';
import {
  AuditLogEntryDTO,
  NavDestination,
  OrganizationDetailsDTO,
  OrgInviteDTO,
  OrgJoinRequestDTO,
  OrgMemberDTO
} from '../types';
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
  Edit2,
  CreditCard,
  Palette,
  Globe,
  KeyRound,
  Download,
  FileText,
  Lock
} from 'lucide-react';

interface TeamScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

export const TeamScreen: React.FC<TeamScreenProps> = ({ onNavigate }) => {
  const [activeTab, setActiveTab] = useState<
    'members' | 'invites' | 'requests' | 'branding' | 'sso' | 'compliance'
  >('members');
  const [members, setMembers] = useState<OrgMemberDTO[]>([]);
  const [invites, setInvites] = useState<OrgInviteDTO[]>([]);
  const [requests, setRequests] = useState<OrgJoinRequestDTO[]>([]);
  const [orgDetails, setOrgDetails] = useState<OrganizationDetailsDTO | null>(null);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntryDTO[]>([]);
  const [loading, setLoading] = useState(true);

  // Governance & Compliance Form State
  const [logoUrl, setLogoUrl] = useState('');
  const [brandColorHex, setBrandColorHex] = useState('#4F46E5');
  const [customDomain, setCustomDomain] = useState('');
  const [allowedEmailDomains, setAllowedEmailDomains] = useState('');
  const [ssoEnabled, setSsoEnabled] = useState(false);
  const [ssoIdpUrl, setSsoIdpUrl] = useState('');
  const [ssoEntityId, setSsoEntityId] = useState('');
  const [ssoCertificate, setSsoCertificate] = useState('');
  const [retentionDays, setRetentionDays] = useState<number | null>(null);
  const [exportFormat, setExportFormat] = useState<'json' | 'csv'>('json');
  const [govSaving, setGovSaving] = useState(false);
  const [govBanner, setGovBanner] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

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

  const applyOrgState = (org: OrganizationDetailsDTO) => {
    setOrgDetails(org);
    setLogoUrl(org.logoUrl || '');
    setBrandColorHex(org.brandColorHex || '#4F46E5');
    setCustomDomain(org.customDomain || '');
    setAllowedEmailDomains(org.allowedEmailDomains || '');
    setSsoEnabled(Boolean(org.ssoEnabled));
    setSsoIdpUrl(org.ssoIdpUrl || '');
    setSsoEntityId(org.ssoEntityId || '');
    setSsoCertificate(org.ssoCertificate || '');
    if (org.retentionDays !== undefined) {
      setRetentionDays(org.retentionDays);
    }
  };

  const fetchData = async () => {
    setLoading(true);
    const orgId = api.getSelectedOrgId() || '';
    try {
      const [membersData, invitesData, requestsData, orgData, retentionData, auditData] = await Promise.all([
        api.getOrgMembers().catch(() => []),
        api.getInvites().catch(() => []),
        api.getJoinRequests().catch(() => []),
        orgId ? api.getOrganization(orgId).catch(() => null) : Promise.resolve(null),
        api.getRetentionPolicy().catch(() => null),
        orgId ? api.getOrgAuditLogs(orgId, 60).catch(() => []) : Promise.resolve([])
      ]);
      setMembers(membersData);
      setInvites(invitesData);
      setRequests(requestsData);
      if (orgData) applyOrgState(orgData);
      if (retentionData) setRetentionDays(retentionData.retentionDays);
      setAuditLogs(auditData);
    } catch (err) {
      console.error('Failed to load team data:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveBranding = async (e: React.FormEvent) => {
    e.preventDefault();
    const orgId = orgDetails?.id || api.getSelectedOrgId();
    if (!orgId) return;
    setGovSaving(true);
    setGovBanner(null);
    try {
      const updated = await api.updateOrganizationBranding(orgId, {
        logoUrl: logoUrl.trim() || null,
        brandColorHex: brandColorHex.trim() || '#4F46E5',
      });
      applyOrgState(updated);
      setGovBanner({ type: 'success', text: 'Custom workspace branding saved.' });
    } catch (err: any) {
      setGovBanner({ type: 'error', text: err.message || 'Failed to save branding.' });
    } finally {
      setGovSaving(false);
    }
  };

  const handleSaveDomains = async (e: React.FormEvent) => {
    e.preventDefault();
    const orgId = orgDetails?.id || api.getSelectedOrgId();
    if (!orgId) return;
    setGovSaving(true);
    setGovBanner(null);
    try {
      const updated = await api.updateOrganizationDomains(orgId, {
        customDomain: customDomain.trim() || null,
        allowedEmailDomains: allowedEmailDomains.trim() || null,
      });
      applyOrgState(updated);
      setGovBanner({ type: 'success', text: 'Custom domain and auto-join email domains saved.' });
    } catch (err: any) {
      setGovBanner({ type: 'error', text: err.message || 'Failed to save domain settings.' });
    } finally {
      setGovSaving(false);
    }
  };

  const handleSaveSSO = async (e: React.FormEvent) => {
    e.preventDefault();
    const orgId = orgDetails?.id || api.getSelectedOrgId();
    if (!orgId) return;
    setGovSaving(true);
    setGovBanner(null);
    try {
      const updated = await api.updateOrganizationSSO(orgId, {
        ssoEnabled,
        ssoIdpUrl: ssoIdpUrl.trim() || null,
        ssoEntityId: ssoEntityId.trim() || null,
        ssoCertificate: ssoCertificate.trim() || null,
      });
      applyOrgState(updated);
      setGovBanner({ type: 'success', text: 'Enterprise SAML 2.0 SSO configuration saved.' });
    } catch (err: any) {
      setGovBanner({ type: 'error', text: err.message || 'Failed to save SSO configuration.' });
    } finally {
      setGovSaving(false);
    }
  };

  const handleSaveRetention = async (days: number | null) => {
    setGovSaving(true);
    setGovBanner(null);
    try {
      const res = await api.updateRetentionPolicy(days);
      setRetentionDays(res.retentionDays);
      setGovBanner({
        type: 'success',
        text: days === null ? 'Retention policy set to Indefinite.' : `Retention policy set to ${days} days.`,
      });
    } catch (err: any) {
      setGovBanner({ type: 'error', text: err.message || 'Failed to update retention policy.' });
    } finally {
      setGovSaving(false);
    }
  };

  const handlePurgeNow = async () => {
    setGovSaving(true);
    setGovBanner(null);
    try {
      const res = await api.purgeExpiredMessagesNow();
      setGovBanner({
        type: 'success',
        text: `Purge completed: ${res.deletedCount} expired message(s) permanently deleted.`,
      });
    } catch (err: any) {
      setGovBanner({ type: 'error', text: err.message || 'Failed to run message purge.' });
    } finally {
      setGovSaving(false);
    }
  };

  const handleExportCompliance = async () => {
    setGovSaving(true);
    setGovBanner(null);
    try {
      const desc = await api.createComplianceExport(exportFormat);
      const blob = await api.downloadComplianceExportBlob(desc.downloadUrl);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `workspace-compliance-export.${desc.format}`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      setGovBanner({
        type: 'success',
        text: `Compliance export (${desc.format.toUpperCase()}, ${desc.sizeBytes} bytes) downloaded.`,
      });
    } catch (err: any) {
      setGovBanner({ type: 'error', text: err.message || 'Failed to generate compliance export.' });
    } finally {
      setGovSaving(false);
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
          {onNavigate && (
            <button
              onClick={() => onNavigate('billing')}
              className="px-3.5 py-2.5 rounded-xl bg-slate-800/90 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center gap-2 text-xs font-semibold shadow-sm cursor-pointer"
            >
              <CreditCard className="w-4 h-4 text-indigo-400" />
              Manage Subscription &amp; Billing
            </button>
          )}

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

        <button
          onClick={() => {
            setGovBanner(null);
            setActiveTab('branding');
          }}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
            activeTab === 'branding'
              ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
          }`}
        >
          <Palette className="w-4 h-4" />
          <span>Branding &amp; Domains</span>
        </button>

        <button
          onClick={() => {
            setGovBanner(null);
            setActiveTab('sso');
          }}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
            activeTab === 'sso'
              ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
          }`}
        >
          <KeyRound className="w-4 h-4" />
          <span>Enterprise SSO</span>
        </button>

        <button
          onClick={() => {
            setGovBanner(null);
            setActiveTab('compliance');
          }}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
            activeTab === 'compliance'
              ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 shadow-sm'
              : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
          }`}
        >
          <ShieldCheck className="w-4 h-4" />
          <span>Retention &amp; Compliance</span>
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

            {/* GOVERNANCE BANNER */}
            {govBanner && (activeTab === 'branding' || activeTab === 'sso' || activeTab === 'compliance') && (
              <div
                className={`mb-5 max-w-4xl p-4 rounded-xl border text-xs font-medium flex items-center justify-between ${
                  govBanner.type === 'success'
                    ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                    : 'bg-red-500/10 border-red-500/30 text-red-300'
                }`}
              >
                <span>{govBanner.text}</span>
                <button onClick={() => setGovBanner(null)} className="text-slate-400 hover:text-white">
                  <X className="w-4 h-4" />
                </button>
              </div>
            )}

            {/* TAB 4: BRANDING & DOMAINS */}
            {activeTab === 'branding' && (
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 max-w-4xl">
                <form
                  onSubmit={handleSaveBranding}
                  className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 space-y-4"
                >
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                      <Palette className="w-4 h-4 text-indigo-400" />
                      Custom Brand Identity
                    </h3>
                    <span className="text-[11px] px-2.5 py-0.5 rounded-full bg-indigo-500/15 text-indigo-300 border border-indigo-500/30 font-semibold uppercase">
                      {orgDetails?.subscriptionTier || 'pro'} tier
                    </span>
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      Workspace Logo URL
                    </label>
                    <input
                      type="url"
                      placeholder="https://cdn.acme.com/logo.svg"
                      value={logoUrl}
                      onChange={(e) => setLogoUrl(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      Brand Accent Color (Hex)
                    </label>
                    <div className="flex items-center gap-3">
                      <input
                        type="color"
                        value={brandColorHex.startsWith('#') && brandColorHex.length === 7 ? brandColorHex : '#4F46E5'}
                        onChange={(e) => setBrandColorHex(e.target.value.toUpperCase())}
                        className="w-10 h-10 rounded-lg bg-slate-950 border border-slate-800 cursor-pointer"
                      />
                      <input
                        type="text"
                        value={brandColorHex}
                        onChange={(e) => setBrandColorHex(e.target.value)}
                        className="flex-1 bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={govSaving}
                    className="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-bold transition shadow-lg shadow-indigo-600/25 cursor-pointer"
                  >
                    {govSaving ? 'Saving...' : 'Save Brand Identity'}
                  </button>
                </form>

                <form
                  onSubmit={handleSaveDomains}
                  className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 space-y-4"
                >
                  <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                    <Globe className="w-4 h-4 text-teal-400" />
                    Custom Domain &amp; Auto-Join Provisioning
                  </h3>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      Custom CNAME Domain
                    </label>
                    <input
                      type="text"
                      placeholder="tasks.acme.com"
                      value={customDomain}
                      onChange={(e) => setCustomDomain(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      Allowed Email Domains (Comma-Separated)
                    </label>
                    <input
                      type="text"
                      placeholder="acme.com, acme.co"
                      value={allowedEmailDomains}
                      onChange={(e) => setAllowedEmailDomains(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                    />
                    <p className="text-[11px] text-slate-500 mt-1.5">
                      Users registering with matching email domains are auto-provisioned as workspace members.
                    </p>
                  </div>

                  <button
                    type="submit"
                    disabled={govSaving}
                    className="w-full py-2.5 rounded-xl bg-teal-600 hover:bg-teal-500 disabled:opacity-50 text-white text-xs font-bold transition shadow-lg shadow-teal-600/20 cursor-pointer"
                  >
                    {govSaving ? 'Saving...' : 'Save Domain Settings'}
                  </button>
                </form>
              </div>
            )}

            {/* TAB 5: ENTERPRISE SSO (SAML 2.0) */}
            {activeTab === 'sso' && (
              <div className="max-w-3xl space-y-6">
                {(orgDetails?.subscriptionTier || 'free').toLowerCase() !== 'enterprise' && (
                  <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-start gap-3">
                    <Lock className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
                    <div className="text-xs text-amber-200">
                      <div className="font-bold">Enterprise Plan Required for SAML 2.0 Single Sign-On</div>
                      <p className="text-amber-300/80 mt-0.5">
                        Upgrade your workspace subscription tier to Enterprise in Billing &amp; Plans to activate SAML 2.0 IdP enforcement.
                      </p>
                    </div>
                  </div>
                )}

                <form
                  onSubmit={handleSaveSSO}
                  className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 space-y-4"
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                        <KeyRound className="w-4 h-4 text-indigo-400" />
                        SAML 2.0 Identity Provider Configuration
                      </h3>
                      <p className="text-xs text-slate-400 mt-0.5">
                        Connect Okta, Azure Entra ID, Google Workspace, or OneLogin
                      </p>
                    </div>
                    <label className="flex items-center gap-2 text-xs font-semibold text-slate-200 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={ssoEnabled}
                        onChange={(e) => setSsoEnabled(e.target.checked)}
                        className="rounded border-slate-700 bg-slate-950 text-indigo-600"
                      />
                      Enable SAML SSO
                    </label>
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      IdP Single Sign-On Target URL
                    </label>
                    <input
                      type="url"
                      placeholder="https://idp.example.com/app/saml2/sso"
                      value={ssoIdpUrl}
                      onChange={(e) => setSsoIdpUrl(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      IdP Entity ID / Issuer URI
                    </label>
                    <input
                      type="text"
                      placeholder="http://www.okta.com/exk1234567890"
                      value={ssoEntityId}
                      onChange={(e) => setSsoEntityId(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                    />
                  </div>

                  <div>
                    <label className="text-xs font-semibold text-slate-400 block mb-1">
                      X.509 Public Certificate (PEM Format)
                    </label>
                    <textarea
                      rows={5}
                      placeholder="-----BEGIN CERTIFICATE-----&#10;MIIDpDCCAoygAwIBAgIGAX...&#10;-----END CERTIFICATE-----"
                      value={ssoCertificate}
                      onChange={(e) => setSsoCertificate(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                    />
                  </div>

                  <button
                    type="submit"
                    disabled={govSaving}
                    className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-bold transition shadow-lg shadow-indigo-600/25 cursor-pointer"
                  >
                    {govSaving ? 'Saving...' : 'Save SAML Configuration'}
                  </button>
                </form>
              </div>
            )}

            {/* TAB 6: RETENTION, COMPLIANCE EXPORT & AUDIT LOG */}
            {activeTab === 'compliance' && (
              <div className="max-w-4xl space-y-6">
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* Message Retention Policy */}
                  <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 space-y-4">
                    <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                      <Clock className="w-4 h-4 text-indigo-400" />
                      Automated Message Retention Policy
                    </h3>
                    <p className="text-xs text-slate-400">
                      Current policy:{' '}
                      <span className="font-bold text-slate-200">
                        {retentionDays == null
                          ? 'Retain messages indefinitely'
                          : `Delete messages older than ${retentionDays} days`}
                      </span>
                    </p>

                    <div className="grid grid-cols-2 gap-2.5">
                      {[
                        { label: '30 Days', days: 30 },
                        { label: '90 Days', days: 90 },
                        { label: '1 Year', days: 365 },
                        { label: 'Indefinite', days: null },
                      ].map((preset) => {
                        const active = retentionDays === preset.days;
                        return (
                          <button
                            key={preset.label}
                            type="button"
                            disabled={govSaving}
                            onClick={() => handleSaveRetention(preset.days)}
                            className={`p-3 rounded-xl border text-left text-xs font-bold transition cursor-pointer ${
                              active
                                ? 'bg-indigo-600/20 border-indigo-500 text-indigo-300'
                                : 'bg-slate-950 border-slate-800 text-slate-300 hover:bg-slate-800/60'
                            }`}
                          >
                            {preset.label}
                          </button>
                        );
                      })}
                    </div>

                    <div className="pt-2 border-t border-slate-800 flex items-center justify-between gap-3">
                      <span className="text-[11px] text-slate-400">
                        Immediately purge messages older than the active retention window
                      </span>
                      <button
                        type="button"
                        disabled={govSaving || retentionDays == null}
                        onClick={handlePurgeNow}
                        className="px-3.5 py-2 rounded-xl bg-red-600/20 hover:bg-red-600/30 disabled:opacity-40 text-red-300 border border-red-500/30 text-xs font-bold shrink-0 cursor-pointer"
                      >
                        Run Purge Now
                      </button>
                    </div>
                  </div>

                  {/* Compliance Archive Export */}
                  <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 flex flex-col justify-between space-y-4">
                    <div className="space-y-3">
                      <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                        <Download className="w-4 h-4 text-emerald-400" />
                        Compliance Archive Export
                      </h3>
                      <p className="text-xs text-slate-400">
                        Generate a signed eDiscovery archive containing organization metadata, member roster, messages, and media upload logs.
                      </p>

                      <div className="grid grid-cols-2 gap-2.5 pt-1">
                        {(['json', 'csv'] as const).map((fmt) => (
                          <button
                            key={fmt}
                            type="button"
                            onClick={() => setExportFormat(fmt)}
                            className={`p-3 rounded-xl border text-xs font-bold uppercase transition cursor-pointer ${
                              exportFormat === fmt
                                ? 'bg-emerald-600/20 border-emerald-500 text-emerald-300'
                                : 'bg-slate-950 border-slate-800 text-slate-400 hover:text-slate-200'
                            }`}
                          >
                            {fmt === 'json' ? 'JSON Bundle (Full)' : 'CSV (Messages)'}
                          </button>
                        ))}
                      </div>
                    </div>

                    <button
                      type="button"
                      disabled={govSaving}
                      onClick={handleExportCompliance}
                      className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-bold transition shadow-lg shadow-emerald-600/25 flex items-center justify-center gap-2 cursor-pointer"
                    >
                      <Download className="w-4 h-4" />
                      {govSaving ? 'Generating Archive...' : 'Generate & Download Export'}
                    </button>
                  </div>
                </div>

                {/* Workspace Audit Trail */}
                <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-6 space-y-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                        <FileText className="w-4 h-4 text-indigo-400" />
                        Recent Workspace Audit Trail
                      </h3>
                      <p className="text-xs text-slate-400">
                        Immutable log of administrative, security, branding, SSO, and compliance actions
                      </p>
                    </div>
                    <button
                      onClick={fetchData}
                      className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold flex items-center gap-1.5 cursor-pointer"
                    >
                      <RefreshCw className="w-3.5 h-3.5" />
                      Refresh
                    </button>
                  </div>

                  {auditLogs.length === 0 ? (
                    <div className="py-8 text-center text-xs text-slate-500">
                      No audit events recorded yet or insufficient role permissions (`audit_log.view`).
                    </div>
                  ) : (
                    <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
                      {auditLogs.map((log) => (
                        <div
                          key={log.id}
                          className="p-3 rounded-xl bg-slate-950/70 border border-slate-800/80 flex flex-wrap items-center justify-between gap-2 text-xs"
                        >
                          <div className="flex items-center gap-2.5">
                            <span className="px-2 py-0.5 rounded-md bg-indigo-500/15 text-indigo-300 border border-indigo-500/30 font-mono font-semibold">
                              {log.action}
                            </span>
                            <span className="text-slate-200 font-medium">{log.userEmail}</span>
                            {log.details && (
                              <span className="text-slate-400 font-mono text-[11px]">{log.details}</span>
                            )}
                          </div>
                          <span className="text-slate-500 text-[11px]">
                            {log.createdAt ? new Date(log.createdAt).toLocaleString() : 'just now'}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
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
