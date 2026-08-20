import React, { useState } from 'react';
import {
  QrCode, Home, Wallet, Gift, Store, ScanLine, Receipt,
  Utensils, ShoppingCart, Coffee, Scissors, Pill, ShoppingBag, Music, Wifi,
  ChevronRight, Check, Users, Menu, X, Globe, Moon, MessageCircle,
  Star, Share2, Download, Phone, RefreshCw, Settings2, Coins, CircleDollarSign,
  Plus, MapPin, Dumbbell, Shirt, Facebook, Mail, User, LogOut, Smartphone, Bell,
} from 'lucide-react';

const STORE_PRESETS = [
  { icon: Utensils, gradient: 'linear-gradient(135deg,#1EA7E0,#0B7EB0)' },
  { icon: ShoppingCart, gradient: 'linear-gradient(135deg,#2FBFA8,#0E8C79)' },
  { icon: Coffee, gradient: 'linear-gradient(135deg,#B07A3E,#8A5A26)' },
  { icon: Scissors, gradient: 'linear-gradient(135deg,#F06B9E,#C7447A)' },
  { icon: Pill, gradient: 'linear-gradient(135deg,#7C6CF0,#4C3FBF)' },
  { icon: Dumbbell, gradient: 'linear-gradient(135deg,#3FC1F0,#1EA7E0)' },
  { icon: Shirt, gradient: 'linear-gradient(135deg,#E7A93E,#C6811E)' },
  { icon: Store, gradient: 'linear-gradient(135deg,#5C7A8A,#2F4855)' },
];
const PRODUCT_PRESETS = [
  { icon: Phone, gradient: 'linear-gradient(135deg,#1EA7E0,#0B7EB0)' },
  { icon: ShoppingBag, gradient: 'linear-gradient(135deg,#2FBFA8,#0E8C79)' },
  { icon: Music, gradient: 'linear-gradient(135deg,#7C6CF0,#4C3FBF)' },
  { icon: Wifi, gradient: 'linear-gradient(135deg,#E7A93E,#C6811E)' },
  { icon: Gift, gradient: 'linear-gradient(135deg,#F06B9E,#C7447A)' },
  { icon: Star, gradient: 'linear-gradient(135deg,#3FC1F0,#1EA7E0)' },
];
const GOVERNORATES = ['دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس', 'إدلب', 'درعا', 'السويداء', 'القنيطرة', 'دير الزور', 'الرقة', 'الحسكة'];

function fmt(n) { return Math.round(n || 0).toLocaleString('en-US'); }
function genEmail(storeName, n) {
  const slug = storeName.replace(/\s+/g, '').slice(0, 6);
  return `${slug}${n}@yallacash.app`.toLowerCase();
}
function genPassword() { return Math.floor(100000 + Math.random() * 900000).toString(); }

const LIGHT = {
  '--surface': '#FFFFFF', '--surface-alt': '#EAF6FC', '--surface-card': '#F3FAFD',
  '--ink': '#0E2A3B', '--ink-soft': 'rgba(14,42,59,0.55)', '--line': 'rgba(14,42,59,0.10)',
  '--primary': '#1EA7E0', '--primary-strong': '#0B7EB0',
  '--gold': '#E7A93E', '--ok': '#1F9D6B', '--danger': '#D9534F',
  '--nav-bg': 'rgba(255,255,255,0.92)',
};
const DARK = {
  '--surface': '#0F2836', '--surface-alt': '#163647', '--surface-card': '#123040',
  '--ink': '#EAF6FC', '--ink-soft': 'rgba(234,246,252,0.6)', '--line': 'rgba(234,246,252,0.12)',
  '--primary': '#3FC1F0', '--primary-strong': '#1EA7E0',
  '--gold': '#F0C06B', '--ok': '#4FD08A', '--danger': '#F27C73',
  '--nav-bg': 'rgba(15,40,54,0.92)',
};

const MENU_ITEMS = [
  { key: 'lang', label: 'اللغة', value: 'العربية', icon: Globe },
  { key: 'dark', label: 'الوضع الداكن', icon: Moon, toggle: true },
  { key: 'contact', label: 'تواصل معنا', icon: MessageCircle },
  { key: 'rate', label: 'قيّم التطبيق', icon: Star },
  { key: 'share', label: 'مشاركة التطبيق', icon: Share2 },
  { key: 'store', label: 'التحميل من المتجر', icon: Download },
  { key: 'logout', label: 'تسجيل الخروج', icon: LogOut },
];

export default function YallaCashPrototype() {
  const [appMode, setAppMode] = useState('customer');
  const [darkMode, setDarkMode] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [pointCashRate, setPointCashRate] = useState(5);

  const [customers, setCustomers] = useState([
    { id: 1, name: 'أحمد الحلبي', phone: '0933000001', governorate: 'حلب', points: 860, joined: '2 آب' },
    { id: 2, name: 'سارة قاسم', phone: '0944000002', governorate: 'دمشق', points: 2100, joined: '28 تموز' },
    { id: 3, name: 'محمد ديب', phone: '0955000003', governorate: 'حمص', points: 430, joined: '5 آب' },
  ]);
  const [currentCustomerId, setCurrentCustomerId] = useState(null);
  const [customerAuthed, setCustomerAuthed] = useState(false);
  const [signupStep, setSignupStep] = useState('method');
  const [signupMethod, setSignupMethod] = useState(null);
  const [signupName, setSignupName] = useState('');
  const [signupGov, setSignupGov] = useState('');
  const [signupPhone, setSignupPhone] = useState('');

  const [transactions, setTransactions] = useState([
    { id: 1, store: 'مطعم الوسيم', amount: 340000, earned: 11, date: '15 آب' },
    { id: 2, store: 'كافيه الزاوية', amount: 90000, earned: 3, date: '13 آب' },
    { id: 3, store: 'ماركت البركة', amount: 520000, earned: 17, date: '10 آب' },
  ]);
  const [settled, setSettled] = useState({});
  const [cashRequests, setCashRequests] = useState([]);
  const [cashPoints, setCashPoints] = useState('');

  const [stores, setStores] = useState([
    { id: 1, name: 'مطعم الوسيم', category: 'مطاعم', commissionRate: 6.7, imageIndex: 0, description: 'مطعم شامي تقليدي بأطباق منزلية', location: 'دمشق - المزة' },
    { id: 2, name: 'ماركت البركة', category: 'سوبرماركت', commissionRate: 5, imageIndex: 1, description: 'ماركت شامل للمواد الغذائية والمنزلية', location: 'دمشق - الميدان' },
    { id: 3, name: 'كافيه الزاوية', category: 'كافيهات', commissionRate: 8, imageIndex: 2, description: 'كافيه هادئ لمحبي القهوة المختصة', location: 'دمشق - أبو رمانة' },
    { id: 4, name: 'صالون لمسة', category: 'صالونات', commissionRate: 7, imageIndex: 3, description: 'صالون عناية وتجميل نسائي', location: 'دمشق - المالكي' },
    { id: 5, name: 'صيدلية الشفاء', category: 'صيدليات', commissionRate: 4, imageIndex: 4, description: 'صيدلية متكاملة على مدار الساعة', location: 'دمشق - ركن الدين' },
  ]);
  const [products, setProducts] = useState([
    { id: 1, name: 'رصيد اتصالات 5$', cost: 500, imageIndex: 0, needsPhone: true },
    { id: 2, name: 'قسيمة تسوق رقمية 10$', cost: 950, imageIndex: 1, needsPhone: false },
    { id: 3, name: 'اشتراك شهر بث موسيقى', cost: 700, imageIndex: 2, needsPhone: false },
    { id: 4, name: 'باقة بيانات إنترنت', cost: 400, imageIndex: 3, needsPhone: false },
  ]);

  const [merchantAccounts, setMerchantAccounts] = useState([
    { id: 1, storeId: 1, email: 'wasim@yallacash.app', password: '123456', devices: [] },
  ]);
  const [merchantAuthed, setMerchantAuthed] = useState(false);
  const [currentMerchantAccountId, setCurrentMerchantAccountId] = useState(null);
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginError, setLoginError] = useState('');

  const [customerTab, setCustomerTab] = useState('home');
  const [expandedStoreId, setExpandedStoreId] = useState(null);
  const [merchantStep, setMerchantStep] = useState('scan');
  const [invoiceAmount, setInvoiceAmount] = useState('');
  const [lastResult, setLastResult] = useState(null);
  const [pendingRedeem, setPendingRedeem] = useState(null);
  const [phoneInput, setPhoneInput] = useState('');
  const [redeemed, setRedeemed] = useState(null);

  const theme = darkMode ? DARK : LIGHT;
  const currentCustomer = customers.find(c => c.id === currentCustomerId) || null;
  const currentMerchantAccount = merchantAccounts.find(a => a.id === currentMerchantAccountId) || null;
  const merchantStore = currentMerchantAccount ? stores.find(s => s.id === currentMerchantAccount.storeId) : null;
  const pendingHeld = currentCustomer ? cashRequests.filter(r => r.customerId === currentCustomer.id).reduce((s, r) => s + r.points, 0) : 0;

  function updateCustomerPoints(id, delta) {
    setCustomers(cs => cs.map(c => (c.id === id ? { ...c, points: Math.max(0, c.points + delta) } : c)));
  }
  function grantPoints(id, amt) { updateCustomerPoints(id, amt); }
  function deductPoints(id, amt) { updateCustomerPoints(id, -amt); }
  function removeCustomer(id) {
    setCustomers(cs => cs.filter(c => c.id !== id));
    if (id === currentCustomerId) { setCustomerAuthed(false); setCurrentCustomerId(null); }
  }

  function updateStore(id, patch) { setStores(ss => ss.map(s => (s.id === id ? { ...s, ...patch } : s))); }
  function cycleStoreImage(id) { setStores(ss => ss.map(s => (s.id === id ? { ...s, imageIndex: (s.imageIndex + 1) % STORE_PRESETS.length } : s))); }
  function addStore() { setStores(ss => [...ss, { id: Date.now(), name: 'محل جديد', category: 'عام', commissionRate: 6.7, imageIndex: 0, description: '', location: '' }]); }

  function updateProduct(id, patch) { setProducts(ps => ps.map(p => (p.id === id ? { ...p, ...patch } : p))); }
  function cycleProductImage(id) { setProducts(ps => ps.map(p => (p.id === id ? { ...p, imageIndex: (p.imageIndex + 1) % PRODUCT_PRESETS.length } : p))); }
  function addProduct() { setProducts(ps => [...ps, { id: Date.now(), name: 'منتج جديد', cost: 100, imageIndex: 0, needsPhone: false }]); }

  function addMerchantAccount(storeId) {
    const store = stores.find(s => s.id === storeId);
    const countForStore = merchantAccounts.filter(a => a.storeId === storeId).length + 1;
    setMerchantAccounts(a => [...a, { id: Date.now(), storeId, email: genEmail(store.name, countForStore), password: genPassword(), devices: [] }]);
  }

  function doMerchantLogin() {
    const acc = merchantAccounts.find(a => a.email.toLowerCase() === loginEmail.trim().toLowerCase() && a.password === loginPassword.trim());
    if (!acc) { setLoginError('بيانات الدخول غير صحيحة — تواصل مع الإدارة للحصول عليها'); return; }
    setMerchantAccounts(as => as.map(a => (a.id === acc.id ? { ...a, devices: [...a.devices, { id: Date.now(), label: `جهاز #${a.devices.length + 1}`, date: 'الآن' }] } : a)));
    setCurrentMerchantAccountId(acc.id);
    setMerchantAuthed(true);
    setLoginError('');
  }
  function merchantLogout() { setMerchantAuthed(false); setCurrentMerchantAccountId(null); setLoginEmail(''); setLoginPassword(''); setMerchantStep('scan'); }

  function completeSignup() {
    const newC = { id: Date.now(), name: signupName || 'مستخدم جديد', phone: signupMethod === 'phone' ? signupPhone : '', governorate: signupGov, points: 1240, joined: 'اليوم' };
    setCustomers(cs => [...cs, newC]);
    setCurrentCustomerId(newC.id);
    setCustomerAuthed(true);
  }
  function customerLogout() {
    setCustomerAuthed(false); setCurrentCustomerId(null); setMenuOpen(false);
    setSignupStep('method'); setSignupMethod(null); setSignupName(''); setSignupGov(''); setSignupPhone('');
  }

  function startRedeem(item) {
    if (!currentCustomer || currentCustomer.points < item.cost) return;
    if (item.needsPhone) { setPendingRedeem(item); setPhoneInput(''); }
    else { doRedeem(item); }
  }
  function doRedeem(item, phone) {
    updateCustomerPoints(currentCustomerId, -item.cost);
    setRedeemed({ kind: 'product', name: item.name, phone });
    setPendingRedeem(null);
    setTimeout(() => setRedeemed(null), 2600);
  }
  function requestCashRedeem() {
    const n = parseInt(cashPoints) || 0;
    const available = currentCustomer.points - pendingHeld;
    if (n <= 0 || n > available) return;
    setCashRequests(rs => [...rs, { id: Date.now(), customerId: currentCustomer.id, customerName: currentCustomer.name, points: n, cashSYP: n * pointCashRate, date: 'الآن', status: 'pending' }]);
    setRedeemed({ kind: 'cash-request', points: n });
    setCashPoints('');
    setTimeout(() => setRedeemed(null), 2600);
  }
  function settleCashRequest(id) {
    const req = cashRequests.find(r => r.id === id);
    if (!req) return;
    updateCustomerPoints(req.customerId, -req.points);
    setCashRequests(rs => rs.filter(r => r.id !== id));
  }
  function rejectCashRequest(id) { setCashRequests(rs => rs.filter(r => r.id !== id)); }

  return (
    <div className="mz-page" dir="rtl">
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@500;700;800&family=Tajawal:wght@400;500;700&display=swap');
        .mz-page { --outer-bg:#0A2333; min-height:100vh; width:100%; background:radial-gradient(circle at 15% 8%, rgba(30,167,224,0.14), transparent 45%), radial-gradient(circle at 85% 90%, rgba(231,169,62,0.08), transparent 45%), var(--outer-bg); display:flex; flex-direction:column; align-items:center; padding:28px 16px 40px; font-family:'Tajawal', sans-serif; }
        .mz-heading { font-family:'Cairo', sans-serif; }
        .mz-switcher { display:inline-flex; background:rgba(255,255,255,0.06); border:1px solid rgba(255,255,255,0.12); border-radius:999px; padding:4px; margin-bottom:22px; gap:4px; }
        .mz-switcher button { border:none; background:transparent; color:rgba(255,255,255,0.55); font-family:'Cairo', sans-serif; font-weight:700; font-size:12.5px; padding:9px 16px; border-radius:999px; cursor:pointer; transition:all .25s ease; white-space:nowrap; }
        .mz-switcher button.active { background:#1EA7E0; color:#06202D; }
        .mz-phone { width:375px; max-width:92vw; border-radius:40px; background:linear-gradient(180deg,#123246,#0A2333); border:1px solid rgba(255,255,255,0.10); box-shadow:0 30px 70px rgba(0,0,0,0.5), inset 0 0 0 8px rgba(0,0,0,0.18); overflow:hidden; position:relative; }
        .mz-notch { width:120px; height:22px; background:#0A2333; border-radius:0 0 16px 16px; margin:0 auto; }
        .mz-screen { height:760px; overflow-y:auto; position:relative; background:var(--surface); color:var(--ink); scrollbar-width:none; transition:background .3s ease, color .3s ease; }
        .mz-screen::-webkit-scrollbar { display:none; }
        .mz-content { padding:18px 18px 90px; }
        .mz-brand { display:flex; align-items:center; justify-content:space-between; margin-bottom:14px; position:relative; }
        .mz-brand-name { font-family:'Cairo', sans-serif; font-weight:800; font-size:20px; color:var(--primary-strong); }
        .mz-brand-sub { font-size:11px; color:var(--ink-soft); margin-top:1px; }
        .mz-icon-btn { width:38px; height:38px; border-radius:12px; background:var(--surface-alt); display:flex; align-items:center; justify-content:center; border:none; cursor:pointer; color:var(--primary-strong); flex-shrink:0; }
        .mz-menu-overlay { position:absolute; inset:0; z-index:10; }
        .mz-menu-panel { position:absolute; top:54px; left:0; width:230px; z-index:11; background:var(--surface); border:1px solid var(--line); border-radius:16px; box-shadow:0 16px 40px rgba(0,0,0,0.25); overflow:hidden; }
        .mz-menu-item { display:flex; align-items:center; gap:10px; padding:12px 14px; font-size:13px; color:var(--ink); border-bottom:1px solid var(--line); cursor:pointer; }
        .mz-menu-item:last-child { border-bottom:none; }
        .mz-menu-item .mz-menu-val { margin-inline-start:auto; font-size:11.5px; color:var(--ink-soft); }
        .mz-switch { width:34px; height:19px; border-radius:999px; background:var(--line); position:relative; margin-inline-start:auto; transition:background .2s; }
        .mz-switch.on { background:var(--primary); }
        .mz-switch::after { content:''; position:absolute; top:2px; right:2px; width:15px; height:15px; border-radius:50%; background:#fff; transition:transform .2s; }
        .mz-switch.on::after { transform:translateX(-15px); }
        .mz-card { background:var(--surface-card); border:1px solid var(--line); border-radius:20px; padding:16px; }
        .mz-balance-card { background:linear-gradient(135deg, var(--primary-strong), var(--primary) 80%); border-radius:22px; padding:20px; position:relative; overflow:hidden; margin-bottom:20px; }
        .mz-balance-card::after { content:''; position:absolute; inset:0; background:radial-gradient(circle at 100% 0%, rgba(255,255,255,0.20), transparent 60%); }
        .mz-balance-label { font-size:12.5px; color:rgba(255,255,255,0.8); position:relative; }
        .mz-balance-num { font-family:'Cairo', sans-serif; font-weight:800; font-size:38px; color:#fff; margin-top:4px; position:relative; }
        .mz-balance-sub { font-size:11px; color:rgba(255,255,255,0.75); position:relative; margin-top:2px; }
        .mz-balance-coins { position:absolute; left:16px; top:16px; }
        .mz-coin { width:34px; height:34px; border-radius:50%; background:linear-gradient(135deg, var(--gold), #C6811E); border:2px solid rgba(255,255,255,0.5); display:flex; align-items:center; justify-content:center; color:#06202D; }
        .mz-section-title { font-family:'Cairo', sans-serif; font-weight:700; font-size:14px; color:var(--ink); margin:20px 0 10px; display:flex; align-items:center; justify-content:space-between; }
        .mz-eyebrow { font-size:10.5px; text-transform:uppercase; letter-spacing:1.2px; color:var(--gold); font-weight:700; }
        .mz-store-row { display:flex; align-items:center; gap:12px; padding:12px 4px; border-bottom:1px solid var(--line); cursor:pointer; }
        .mz-store-row:last-child { border-bottom:none; }
        .mz-store-icon { width:42px; height:42px; border-radius:13px; background:var(--surface-alt); display:flex; align-items:center; justify-content:center; color:var(--primary-strong); flex-shrink:0; }
        .mz-store-name { font-weight:600; font-size:14.5px; color:var(--ink); }
        .mz-store-cat { font-size:11.5px; color:var(--ink-soft); margin-top:1px; }
        .mz-exclusive-tag { font-size:9.5px; font-weight:700; background:rgba(31,157,107,0.14); color:var(--ok); padding:2px 8px; border-radius:999px; margin-inline-start:auto; }
        .mz-store-detail { padding:4px 4px 14px 58px; font-size:12px; color:var(--ink-soft); line-height:1.8; border-bottom:1px solid var(--line); }
        .mz-store-detail .row { display:flex; align-items:center; gap:6px; margin-top:3px; }
        .mz-bottom-nav { position:absolute; bottom:0; right:0; left:0; background:var(--nav-bg); backdrop-filter:blur(10px); border-top:1px solid var(--line); display:flex; padding:10px 8px 16px; }
        .mz-nav-btn { flex:1; display:flex; flex-direction:column; align-items:center; gap:4px; background:none; border:none; cursor:pointer; color:var(--ink-soft); font-size:10.5px; font-family:'Tajawal', sans-serif; padding:6px 0; }
        .mz-nav-btn.active { color:var(--primary-strong); }
        .mz-qr-box { background:var(--surface-alt); border-radius:20px; padding:28px; display:flex; align-items:center; justify-content:center; margin:10px 0 18px; }
        .mz-btn-primary { width:100%; background:var(--primary); color:#fff; border:none; border-radius:14px; padding:14px; font-family:'Cairo', sans-serif; font-weight:800; font-size:14.5px; cursor:pointer; transition:transform .15s ease, filter .15s ease; }
        .mz-btn-primary:active { transform:scale(0.97); }
        .mz-btn-primary:disabled { opacity:0.35; cursor:not-allowed; }
        .mz-btn-ghost { background:transparent; color:var(--ink); border:1px solid var(--line); border-radius:14px; padding:10px 14px; font-family:'Tajawal', sans-serif; font-weight:500; font-size:12.5px; cursor:pointer; }
        .mz-btn-dashed { width:100%; background:transparent; color:var(--primary-strong); border:1.5px dashed var(--primary); border-radius:14px; padding:12px; font-family:'Cairo', sans-serif; font-weight:700; font-size:13px; cursor:pointer; display:flex; align-items:center; justify-content:center; gap:6px; margin-bottom:16px; }
        .mz-input { width:100%; background:var(--surface-alt); border:1px solid var(--line); border-radius:14px; padding:16px; color:var(--ink); font-family:'Cairo', sans-serif; font-size:26px; font-weight:800; text-align:center; outline:none; }
        .mz-input:focus { border-color:var(--primary); }
        .mz-input-sm { width:100%; background:var(--surface-alt); border:1px solid var(--line); border-radius:12px; padding:11px 12px; color:var(--ink); font-family:'Tajawal', sans-serif; font-size:13.5px; outline:none; }
        .mz-input-sm:focus { border-color:var(--primary); }
        textarea.mz-input-sm { resize:none; font-family:'Tajawal', sans-serif; }
        select.mz-input-sm { appearance:none; cursor:pointer; }
        .mz-auth-option { display:flex; align-items:center; gap:10px; width:100%; padding:13px 16px; border-radius:14px; border:1px solid var(--line); background:var(--surface-alt); color:var(--ink); font-family:'Tajawal', sans-serif; font-weight:500; font-size:13.5px; cursor:pointer; }
        .mz-fade-in { animation:mzFade .35s ease both; }
        @keyframes mzFade { from { opacity:0; transform:translateY(6px);} to {opacity:1; transform:none;} }
        .mz-scan-frame { width:100%; aspect-ratio:1; border:2px dashed var(--primary); border-radius:24px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:10px; background:var(--surface-alt); color:var(--primary-strong); margin:10px 0 18px; }
        .mz-stat-grid { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:16px; }
        .mz-stat { background:var(--surface-card); border:1px solid var(--line); border-radius:16px; padding:13px; }
        .mz-stat-num { font-family:'Cairo',sans-serif; font-weight:800; font-size:19px; color:var(--primary-strong); }
        .mz-stat-label { font-size:10.5px; color:var(--ink-soft); margin-top:3px; }
        .mz-tile { width:46px; height:46px; border-radius:13px; display:flex; align-items:center; justify-content:center; color:#fff; flex-shrink:0; }
        .mz-admin-row { display:flex; align-items:flex-start; gap:12px; padding:12px; border:1px solid var(--line); border-radius:16px; margin-bottom:10px; background:var(--surface-card); }
        .mz-admin-fields { flex:1; display:flex; flex-direction:column; gap:6px; }
        .mz-admin-fields-row { display:flex; gap:6px; }
        .mz-checkbox-row { display:flex; align-items:center; gap:6px; font-size:11px; color:var(--ink-soft); margin-top:2px; }
        .mz-field-label { font-size:10px; color:var(--ink-soft); margin-bottom:2px; display:block; }
        .mz-settle-row { display:flex; align-items:center; gap:10px; padding:12px; border-bottom:1px solid var(--line); }
        .mz-settle-row:last-child { border-bottom:none; }
        @media (prefers-reduced-motion: reduce) { .mz-fade-in, .mz-btn-primary { animation:none !important; transition:none !important; } }
      `}</style>

      <div style={{ textAlign: 'center', marginBottom: 4 }}>
        <div className="mz-eyebrow mz-heading">نموذج تفاعلي — غير مخصص للاستخدام الفعلي</div>
        <div className="mz-heading" style={{ fontSize: 22, fontWeight: 800, color: '#fff', marginTop: 4 }}>يلا كاش <span style={{ color: '#3FC1F0' }}>— كاش باك من محلاتك المفضّلة</span></div>
      </div>

      <div className="mz-switcher">
        <button className={appMode === 'customer' ? 'active' : ''} onClick={() => { setAppMode('customer'); setMenuOpen(false); }}>تطبيق الزبون</button>
        <button className={appMode === 'merchant' ? 'active' : ''} onClick={() => { setAppMode('merchant'); setMenuOpen(false); }}>تطبيق المحل</button>
        <button className={appMode === 'admin' ? 'active' : ''} onClick={() => { setAppMode('admin'); setMenuOpen(false); }}>لوحة التحكم</button>
      </div>

      <div className="mz-phone">
        <div className="mz-notch" />
        <div className="mz-screen" style={theme}>
          {appMode === 'customer' && !customerAuthed && (
            <CustomerAuth
              step={signupStep} setStep={setSignupStep} method={signupMethod} setMethod={setSignupMethod}
              name={signupName} setName={setSignupName} gov={signupGov} setGov={setSignupGov}
              phone={signupPhone} setPhone={setSignupPhone} onComplete={completeSignup}
            />
          )}
          {appMode === 'customer' && customerAuthed && currentCustomer && (
            <CustomerApp
              tab={customerTab} setTab={setCustomerTab}
              customer={currentCustomer} pendingHeld={pendingHeld}
              transactions={transactions} stores={stores} products={products} pointCashRate={pointCashRate}
              redeemed={redeemed} pendingRedeem={pendingRedeem}
              phoneInput={phoneInput} setPhoneInput={setPhoneInput}
              onStartRedeem={startRedeem}
              onConfirmPhoneRedeem={() => pendingRedeem && doRedeem(pendingRedeem, phoneInput)}
              onCancelRedeem={() => setPendingRedeem(null)}
              menuOpen={menuOpen} setMenuOpen={setMenuOpen}
              darkMode={darkMode} setDarkMode={setDarkMode}
              expandedStoreId={expandedStoreId} setExpandedStoreId={setExpandedStoreId}
              cashPoints={cashPoints} setCashPoints={setCashPoints} onCashRedeem={requestCashRedeem}
              onLogout={customerLogout}
            />
          )}

          {appMode === 'merchant' && !merchantAuthed && (
            <MerchantAuth email={loginEmail} setEmail={setLoginEmail} password={loginPassword} setPassword={setLoginPassword} error={loginError} onLogin={doMerchantLogin} />
          )}
          {appMode === 'merchant' && merchantAuthed && merchantStore && (
            <MerchantApp
              store={merchantStore}
              step={merchantStep} setStep={setMerchantStep}
              amount={invoiceAmount} setAmount={setInvoiceAmount}
              lastResult={lastResult} transactions={transactions}
              onLogout={merchantLogout}
              onConfirm={() => {
                const raw = parseFloat(invoiceAmount) || 0;
                const commission = raw * (merchantStore.commissionRate / 100);
                const half = Math.round(commission / 2);
                setLastResult({ raw, commission: Math.round(commission) });
                if (currentCustomerId) updateCustomerPoints(currentCustomerId, half);
                setTransactions(tx => [{ id: Date.now(), store: merchantStore.name, amount: raw, earned: half, date: 'الآن' }, ...tx]);
                setMerchantStep('success');
              }}
              onReset={() => { setInvoiceAmount(''); setMerchantStep('scan'); setLastResult(null); }}
            />
          )}

          {appMode === 'admin' && (
            <AdminApp
              customers={customers} onGrant={grantPoints} onDeduct={deductPoints} onRemoveCustomer={removeCustomer}
              cashRequests={cashRequests} onSettleCash={settleCashRequest} onRejectCash={rejectCashRequest}
              products={products} onUpdateProduct={updateProduct} onCycleProductImage={cycleProductImage} onAddProduct={addProduct}
              stores={stores} onUpdateStore={updateStore} onCycleStoreImage={cycleStoreImage} onAddStore={addStore}
              merchantAccounts={merchantAccounts} onAddAccount={addMerchantAccount}
              transactions={transactions} settled={settled} onToggleSettled={(id) => setSettled(s => ({ ...s, [id]: !s[id] }))}
              pointCashRate={pointCashRate} setPointCashRate={setPointCashRate}
            />
          )}
        </div>
      </div>

      <p style={{ fontSize: 11.5, color: 'rgba(255,255,255,0.4)', marginTop: 18, maxWidth: 340, textAlign: 'center', lineHeight: 1.7 }}>
        هذا نموذج أولي لتجربة الفكرة فقط — الأرقام والمحلات تجريبية بالكامل، ولا يوجد مصادقة أو تخزين حقيقي.
      </p>
    </div>
  );
}

function CustomerAuth({ step, setStep, method, setMethod, name, setName, gov, setGov, phone, setPhone, onComplete }) {
  if (step === 'method') {
    return (
      <div className="mz-content mz-fade-in" style={{ paddingTop: 46 }}>
        <div style={{ textAlign: 'center', marginBottom: 26 }}>
          <div className="mz-brand-name" style={{ fontSize: 24 }}>يلا كاش</div>
          <div className="mz-brand-sub">أنشئ حسابك وابدأ تجمع نقاطك</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button className="mz-auth-option" onClick={() => { setMethod('facebook'); setStep('details'); }}><Facebook size={17} color="#1877F2" /> المتابعة عبر فيسبوك</button>
          <button className="mz-auth-option" onClick={() => { setMethod('gmail'); setStep('details'); }}><Mail size={17} color="#EA4335" /> المتابعة عبر جيميل</button>
          <button className="mz-auth-option" onClick={() => { setMethod('phone'); setStep('details'); }}><Phone size={17} color="var(--primary-strong)" /> المتابعة برقم الهاتف</button>
        </div>
      </div>
    );
  }
  return (
    <div className="mz-content mz-fade-in" style={{ paddingTop: 34 }}>
      <div style={{ textAlign: 'center', marginBottom: 20 }}>
        <div className="mz-brand-name" style={{ fontSize: 19 }}>أكمل بياناتك</div>
        <div className="mz-brand-sub">خطوة أخيرة لإنشاء حسابك</div>
      </div>
      {method === 'phone' ? (
        <div style={{ marginBottom: 10 }}>
          <label className="mz-field-label">رقم الهاتف</label>
          <input className="mz-input-sm" placeholder="09xxxxxxxx" value={phone} onChange={e => setPhone(e.target.value)} />
        </div>
      ) : (
        <div className="mz-card" style={{ marginBottom: 12, fontSize: 12, color: 'var(--ink-soft)' }}>
          سيتم جلب اسمك من حساب {method === 'facebook' ? 'فيسبوك' : 'جيميل'} تلقائيًا (محاكاة للعرض فقط).
        </div>
      )}
      <div style={{ marginBottom: 10 }}>
        <label className="mz-field-label">الاسم الكامل</label>
        <input className="mz-input-sm" placeholder="مثال: محمد أحمد" value={name} onChange={e => setName(e.target.value)} />
      </div>
      <div style={{ marginBottom: 18 }}>
        <label className="mz-field-label">المحافظة</label>
        <select className="mz-input-sm" value={gov} onChange={e => setGov(e.target.value)}>
          <option value="">اختر المحافظة</option>
          {GOVERNORATES.map(g => <option key={g} value={g}>{g}</option>)}
        </select>
      </div>
      <button className="mz-btn-primary" disabled={!name || !gov || (method === 'phone' && phone.trim().length < 8)} onClick={onComplete}>إنشاء الحساب</button>
      <button className="mz-btn-ghost" style={{ width: '100%', marginTop: 8 }} onClick={() => setStep('method')}>رجوع</button>
    </div>
  );
}

function MerchantAuth({ email, setEmail, password, setPassword, error, onLogin }) {
  return (
    <div className="mz-content mz-fade-in" style={{ paddingTop: 60 }}>
      <div style={{ textAlign: 'center', marginBottom: 26 }}>
        <div className="mz-brand-name" style={{ fontSize: 21 }}>يلا كاش للمحلات</div>
        <div className="mz-brand-sub">سجّل الدخول ببيانات حسابك</div>
      </div>
      <label className="mz-field-label">البريد الإلكتروني</label>
      <input className="mz-input-sm" style={{ marginBottom: 12 }} value={email} onChange={e => setEmail(e.target.value)} placeholder="store@yallacash.app" />
      <label className="mz-field-label">كلمة المرور</label>
      <input className="mz-input-sm" type="password" style={{ marginBottom: 14 }} value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••" />
      {error && <div style={{ fontSize: 11.5, color: 'var(--danger)', marginBottom: 10 }}>{error}</div>}
      <button className="mz-btn-primary" disabled={!email || !password} onClick={onLogin}>تسجيل الدخول</button>
      <p style={{ fontSize: 11, color: 'var(--ink-soft)', textAlign: 'center', marginTop: 14, lineHeight: 1.8 }}>
        بيانات الدخول تُصدَر من الإدارة.<br />للتجربة: wasim@yallacash.app / 123456
      </p>
    </div>
  );
}

function CustomerApp({
  tab, setTab, customer, pendingHeld, transactions, stores, products, pointCashRate,
  redeemed, pendingRedeem, phoneInput, setPhoneInput, onStartRedeem, onConfirmPhoneRedeem, onCancelRedeem,
  menuOpen, setMenuOpen, darkMode, setDarkMode, expandedStoreId, setExpandedStoreId,
  cashPoints, setCashPoints, onCashRedeem, onLogout,
}) {
  const available = customer.points - pendingHeld;
  const cashValue = (parseInt(cashPoints) || 0) * pointCashRate;

  return (
    <div className="mz-content mz-fade-in" key={tab}>
      <div className="mz-brand">
        <div><div className="mz-brand-name">يلا كاش</div><div className="mz-brand-sub">مرحبًا {customer.name.split(' ')[0]} 👋</div></div>
        <button className="mz-icon-btn" onClick={() => setMenuOpen(o => !o)}>{menuOpen ? <X size={16} /> : <Menu size={16} />}</button>
        {menuOpen && (
          <>
            <div className="mz-menu-overlay" onClick={() => setMenuOpen(false)} />
            <div className="mz-menu-panel">
              {MENU_ITEMS.map(item => (
                <div className="mz-menu-item" key={item.key} onClick={() => { if (item.key === 'dark') setDarkMode(d => !d); if (item.key === 'logout') onLogout(); }}>
                  <item.icon size={15} color={item.key === 'logout' ? 'var(--danger)' : 'var(--primary-strong)'} />
                  <span style={{ color: item.key === 'logout' ? 'var(--danger)' : 'var(--ink)' }}>{item.label}</span>
                  {item.value && <span className="mz-menu-val">{item.value}</span>}
                  {item.toggle && <span className={`mz-switch ${darkMode ? 'on' : ''}`} />}
                  {!item.value && !item.toggle && item.key !== 'logout' && <ChevronRight size={13} color="var(--ink-soft)" />}
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      {tab === 'home' && (
        <>
          <div className="mz-balance-card">
            <div className="mz-balance-coins"><div className="mz-coin"><Coins size={16} /></div></div>
            <div className="mz-balance-label">رصيد النقاط</div>
            <div className="mz-balance-num">{fmt(customer.points)}</div>
            {pendingHeld > 0 && <div className="mz-balance-sub">منها {fmt(pendingHeld)} نقطة قيد المعالجة</div>}
          </div>
          <div className="mz-section-title"><span>المحلات الحصرية بمدينتك</span></div>
          <div className="mz-card">
            {stores.map(s => {
              const preset = STORE_PRESETS[s.imageIndex];
              const open = expandedStoreId === s.id;
              return (
                <React.Fragment key={s.id}>
                  <div className="mz-store-row" onClick={() => setExpandedStoreId(open ? null : s.id)}>
                    <div className="mz-tile" style={{ background: preset.gradient, width: 42, height: 42, borderRadius: 13 }}><preset.icon size={18} /></div>
                    <div><div className="mz-store-name">{s.name}</div><div className="mz-store-cat">{s.category}</div></div>
                    <span className="mz-exclusive-tag">حصري</span>
                  </div>
                  {open && (
                    <div className="mz-store-detail mz-fade-in">
                      {s.description && <div>{s.description}</div>}
                      {s.location && <div className="row"><MapPin size={12} /> {s.location}</div>}
                    </div>
                  )}
                </React.Fragment>
              );
            })}
          </div>
        </>
      )}

      {tab === 'qr' && (
        <>
          <div className="mz-section-title"><span>كودك الشخصي</span></div>
          <div className="mz-qr-box"><MockQR /></div>
          <p style={{ fontSize: 12.5, color: 'var(--ink-soft)', textAlign: 'center', lineHeight: 1.8 }}>اعرض هذا الكود على الكاشير عند الدفع، وبتنضاف نقاطك تلقائيًا بعد المسح.</p>
        </>
      )}

      {tab === 'wallet' && (
        <>
          <div className="mz-section-title"><span>سجل العمليات</span></div>
          <div className="mz-card">
            {transactions.map(t => (
              <div className="mz-store-row" key={t.id} style={{ cursor: 'default' }}>
                <div className="mz-store-icon"><Receipt size={17} /></div>
                <div style={{ flex: 1 }}><div className="mz-store-name">{t.store}</div><div className="mz-store-cat">{t.date} · فاتورة {fmt(t.amount)} ل.س</div></div>
                <div style={{ color: 'var(--primary-strong)', fontFamily: 'Cairo', fontWeight: 700, fontSize: 13.5 }}>+{t.earned}</div>
              </div>
            ))}
          </div>
        </>
      )}

      {tab === 'store' && (
        <>
          <div className="mz-balance-card" style={{ padding: 14 }}>
            <div className="mz-balance-label">رصيدك المتاح</div>
            <div className="mz-balance-num" style={{ fontSize: 26 }}>{fmt(available)} نقطة</div>
          </div>

          {redeemed && (
            <div className="mz-card mz-fade-in" style={{ borderColor: 'var(--ok)', marginBottom: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
              <Check size={17} color="var(--ok)" />
              <span style={{ fontSize: 13 }}>
                {redeemed.kind === 'cash-request'
                  ? `تم إرسال طلب استبدال ${fmt(redeemed.points)} نقطة بكاش، بانتظار المحاسبة من الإدارة`
                  : `تم استبدال «${redeemed.name}»${redeemed.phone ? ` — سيتم تحويل الرصيد إلى ${redeemed.phone}` : ''}`}
              </span>
            </div>
          )}

          <div className="mz-section-title"><span>استبدال نقاط بكاش</span></div>
          <div className="mz-card" style={{ marginBottom: 16 }}>
            <label className="mz-field-label">عدد النقاط</label>
            <input className="mz-input-sm" type="number" placeholder="مثال: 200" value={cashPoints} onChange={e => setCashPoints(e.target.value)} style={{ marginBottom: 10 }} />
            <div style={{ fontSize: 12.5, color: 'var(--ink-soft)', marginBottom: 10 }}>يعادل: <b style={{ color: 'var(--ink)' }}>{fmt(cashValue)} ل.س</b></div>
            <button className="mz-btn-primary" disabled={!cashPoints || parseInt(cashPoints) <= 0 || parseInt(cashPoints) > available} onClick={onCashRedeem}>إرسال طلب الاستبدال</button>
          </div>

          <div className="mz-section-title"><span>استبدل نقاطك بمنتجات رقمية</span></div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {products.map(item => {
              const preset = PRODUCT_PRESETS[item.imageIndex];
              const isPending = pendingRedeem && pendingRedeem.id === item.id;
              return (
                <div className="mz-card" key={item.id}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div className="mz-tile" style={{ background: preset.gradient }}><preset.icon size={19} /></div>
                    <div style={{ flex: 1 }}><div className="mz-store-name">{item.name}</div><div className="mz-store-cat">{fmt(item.cost)} نقطة</div></div>
                    <button className="mz-btn-ghost" style={{ opacity: available < item.cost ? 0.35 : 1 }} disabled={available < item.cost} onClick={() => onStartRedeem(item)}>استبدال</button>
                  </div>
                  {isPending && (
                    <div className="mz-fade-in" style={{ marginTop: 12, paddingTop: 12, borderTop: '1px solid var(--line)' }}>
                      <label className="mz-field-label">رقم الهاتف المراد تحويل الرصيد عليه</label>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <input className="mz-input-sm" placeholder="09xxxxxxxx" value={phoneInput} onChange={e => setPhoneInput(e.target.value)} />
                        <button className="mz-btn-primary" style={{ width: 'auto', padding: '0 16px' }} disabled={phoneInput.trim().length < 8} onClick={onConfirmPhoneRedeem}>تأكيد</button>
                      </div>
                      <button className="mz-btn-ghost" style={{ marginTop: 8, fontSize: 11.5, padding: '6px 12px' }} onClick={onCancelRedeem}>إلغاء</button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </>
      )}

      <div className="mz-bottom-nav">
        <NavBtn icon={Home} label="الرئيسية" active={tab === 'home'} onClick={() => setTab('home')} />
        <NavBtn icon={QrCode} label="كودي" active={tab === 'qr'} onClick={() => setTab('qr')} />
        <NavBtn icon={Wallet} label="المحفظة" active={tab === 'wallet'} onClick={() => setTab('wallet')} />
        <NavBtn icon={Store} label="المتجر" active={tab === 'store'} onClick={() => setTab('store')} />
      </div>
    </div>
  );
}

function MerchantApp({ store, step, setStep, amount, setAmount, onConfirm, lastResult, onReset, transactions, onLogout }) {
  const myTx = transactions.filter(t => t.store === store.name);
  const sales = myTx.reduce((s, t) => s + t.amount, 0);
  const commission = sales * (store.commissionRate / 100);

  return (
    <div className="mz-content mz-fade-in" key={step}>
      <div className="mz-brand">
        <div><div className="mz-brand-name">يلا كاش للمحلات</div><div className="mz-brand-sub">{store.name}</div></div>
        <button className="mz-icon-btn" onClick={onLogout}><LogOut size={16} /></button>
      </div>

      <div className="mz-stat-grid">
        <div className="mz-stat"><div className="mz-stat-num">{myTx.length}</div><div className="mz-stat-label">عدد المبيعات</div></div>
        <div className="mz-stat"><div className="mz-stat-num">{fmt(sales)}</div><div className="mz-stat-label">قيمة المبيعات (ل.س)</div></div>
        <div className="mz-stat" style={{ gridColumn: '1 / -1' }}><div className="mz-stat-num">{fmt(commission)} ل.س</div><div className="mz-stat-label">العمولة المستحقة عليك (نسبتك {store.commissionRate}%)</div></div>
      </div>

      {step === 'scan' && (
        <>
          <div className="mz-section-title"><span>مسح كود الزبون</span></div>
          <div className="mz-scan-frame"><ScanLine size={36} /><span style={{ fontSize: 12.5 }}>وجّه الكاميرا نحو كود الزبون</span></div>
          <button className="mz-btn-primary" onClick={() => setStep('amount')}>تم مسح الكود ✓</button>
        </>
      )}

      {step === 'amount' && (
        <>
          <div className="mz-section-title"><span>إضافة الفاتورة</span></div>
          <div className="mz-card" style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div className="mz-store-icon"><Users size={17} /></div>
            <div><div className="mz-store-name">زبون رقم #4471</div><div className="mz-store-cat">تم التحقق من الكود بنجاح</div></div>
          </div>
          <label className="mz-field-label">قيمة الفاتورة (ل.س)</label>
          <input className="mz-input" type="number" placeholder="0" value={amount} onChange={e => setAmount(e.target.value)} style={{ marginBottom: 16 }} />
          <button className="mz-btn-primary" disabled={!amount || parseFloat(amount) <= 0} onClick={onConfirm}>تأكيد العملية</button>
        </>
      )}

      {step === 'success' && lastResult && (
        <>
          <div className="mz-card mz-fade-in" style={{ borderColor: 'var(--ok)', textAlign: 'center', padding: 22, marginBottom: 16 }}>
            <div style={{ width: 46, height: 46, borderRadius: '50%', background: 'rgba(31,157,107,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 10px' }}>
              <Check size={22} color="var(--ok)" />
            </div>
            <div className="mz-heading" style={{ fontWeight: 700, fontSize: 15 }}>تمت العملية بنجاح</div>
            <div style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 4 }}>فاتورة بقيمة {fmt(lastResult.raw)} ل.س</div>
          </div>
          <div className="mz-card" style={{ marginBottom: 8, display: 'flex', alignItems: 'center', gap: 12 }}>
            <div className="mz-store-icon"><CircleDollarSign size={19} /></div>
            <div style={{ flex: 1 }}><div className="mz-store-name">العمولة المستحقة عليك</div><div className="mz-store-cat">{fmt(lastResult.commission)} ل.س</div></div>
          </div>
          <p style={{ fontSize: 11.5, color: 'var(--ink-soft)', textAlign: 'center', margin: '10px 0 16px', lineHeight: 1.8 }}>🗓 يتم التحاسب نقدًا مطلع كل شهر بناءً على مجموع عملياتك المسجّلة.</p>
          <button className="mz-btn-primary" onClick={onReset}>عملية جديدة</button>
        </>
      )}
    </div>
  );
}

function UserRow({ c, onGrant, onDeduct, onRemove }) {
  const [amt, setAmt] = useState('');
  return (
    <div className="mz-settle-row">
      <div className="mz-store-icon"><User size={17} /></div>
      <div style={{ flex: 1 }}>
        <div className="mz-store-name">{c.name}</div>
        <div className="mz-store-cat">{c.governorate} · {fmt(c.points)} نقطة · انضم {c.joined}</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4, alignItems: 'flex-end' }}>
        <input className="mz-input-sm" style={{ width: 68, padding: '6px 8px', fontSize: 11.5 }} placeholder="عدد" value={amt} onChange={e => setAmt(e.target.value)} />
        <div style={{ display: 'flex', gap: 4 }}>
          <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '4px 7px' }} onClick={() => { if (amt) { onGrant(c.id, parseInt(amt)); setAmt(''); } }}>منح</button>
          <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '4px 7px' }} onClick={() => { if (amt) { onDeduct(c.id, parseInt(amt)); setAmt(''); } }}>خصم</button>
          <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '4px 7px', color: 'var(--danger)' }} onClick={() => onRemove(c.id)}>حذف</button>
        </div>
      </div>
    </div>
  );
}

function AdminApp({
  customers, onGrant, onDeduct, onRemoveCustomer, cashRequests, onSettleCash, onRejectCash,
  products, onUpdateProduct, onCycleProductImage, onAddProduct,
  stores, onUpdateStore, onCycleStoreImage, onAddStore,
  merchantAccounts, onAddAccount,
  transactions, settled, onToggleSettled, pointCashRate, setPointCashRate,
}) {
  return (
    <div className="mz-content mz-fade-in">
      <div className="mz-brand">
        <div><div className="mz-brand-name">يلا كاش</div><div className="mz-brand-sub">لوحة التحكم</div></div>
        <div className="mz-icon-btn"><Settings2 size={17} /></div>
      </div>

      <div className="mz-section-title"><span>إعدادات عامة</span></div>
      <div className="mz-card" style={{ marginBottom: 16 }}>
        <label className="mz-field-label">قيمة النقطة نقدًا (ل.س)</label>
        <input className="mz-input-sm" type="number" value={pointCashRate} onChange={e => setPointCashRate(parseFloat(e.target.value) || 0)} />
      </div>

      <div className="mz-section-title"><span>المستخدمون</span></div>
      <div className="mz-card" style={{ marginBottom: 16, padding: 4 }}>
        {customers.length === 0 && <div className="mz-empty-note">لا يوجد مستخدمون بعد</div>}
        {customers.map(c => <UserRow key={c.id} c={c} onGrant={onGrant} onDeduct={onDeduct} onRemove={onRemoveCustomer} />)}
      </div>

      <div className="mz-section-title"><span>طلبات استبدال النقاط بكاش</span></div>
      <div className="mz-card" style={{ marginBottom: 16, padding: 4 }}>
        {cashRequests.length === 0 && <div className="mz-empty-note">لا توجد طلبات بانتظار المحاسبة</div>}
        {cashRequests.map(r => (
          <div className="mz-settle-row" key={r.id}>
            <div className="mz-store-icon"><Bell size={17} /></div>
            <div style={{ flex: 1 }}>
              <div className="mz-store-name">{r.customerName}</div>
              <div className="mz-store-cat">{fmt(r.points)} نقطة · {fmt(r.cashSYP)} ل.س · {r.date}</div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '5px 9px', color: 'var(--ok)' }} onClick={() => onSettleCash(r.id)}>تمت المحاسبة — حذف النقاط</button>
              <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '5px 9px', color: 'var(--danger)' }} onClick={() => onRejectCash(r.id)}>إلغاء الطلب</button>
            </div>
          </div>
        ))}
      </div>

      <div className="mz-section-title"><span>إدارة المحلات</span></div>
      {stores.map(s => {
        const preset = STORE_PRESETS[s.imageIndex];
        return (
          <div className="mz-admin-row" key={s.id}>
            <div>
              <div className="mz-tile" style={{ background: preset.gradient, marginBottom: 6 }}><preset.icon size={19} /></div>
              <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '5px 7px', display: 'flex', alignItems: 'center', gap: 4 }} onClick={() => onCycleStoreImage(s.id)}><RefreshCw size={10} /> الصورة</button>
            </div>
            <div className="mz-admin-fields">
              <div className="mz-admin-fields-row">
                <input className="mz-input-sm" value={s.name} onChange={e => onUpdateStore(s.id, { name: e.target.value })} placeholder="اسم المحل" />
                <input className="mz-input-sm" value={s.category} onChange={e => onUpdateStore(s.id, { category: e.target.value })} placeholder="القطاع" />
              </div>
              <div className="mz-admin-fields-row">
                <div style={{ flex: 1 }}><label className="mz-field-label">نسبة العمولة %</label><input className="mz-input-sm" type="number" step="0.1" value={s.commissionRate} onChange={e => onUpdateStore(s.id, { commissionRate: parseFloat(e.target.value) || 0 })} /></div>
                <div style={{ flex: 1 }}><label className="mz-field-label">الموقع</label><input className="mz-input-sm" value={s.location} onChange={e => onUpdateStore(s.id, { location: e.target.value })} placeholder="المدينة - الحي" /></div>
              </div>
              <div><label className="mz-field-label">وصف المحل (يظهر للزبون)</label><textarea className="mz-input-sm" rows={2} value={s.description} onChange={e => onUpdateStore(s.id, { description: e.target.value })} placeholder="نبذة قصيرة عن المحل..." /></div>
            </div>
          </div>
        );
      })}
      <button className="mz-btn-dashed" onClick={onAddStore}><Plus size={15} /> إضافة محل جديد</button>

      <div className="mz-section-title"><span>حسابات دخول المحلات</span></div>
      {stores.map(s => {
        const accounts = merchantAccounts.filter(a => a.storeId === s.id);
        return (
          <div className="mz-card" key={s.id} style={{ marginBottom: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: accounts.length ? 8 : 0 }}>
              <div className="mz-store-name">{s.name}</div>
              <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '4px 8px', marginInlineStart: 'auto', display: 'flex', alignItems: 'center', gap: 4 }} onClick={() => onAddAccount(s.id)}><Plus size={11} /> توليد بريد جديد</button>
            </div>
            {accounts.map(a => (
              <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 0', borderTop: '1px solid var(--line)' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12.5, fontFamily: 'Cairo', fontWeight: 600 }}>{a.email}</div>
                  <div style={{ fontSize: 11, color: 'var(--ink-soft)' }}>كلمة المرور: {a.password}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: 'var(--ink-soft)' }}><Smartphone size={13} /> {a.devices.length} جهاز</div>
              </div>
            ))}
          </div>
        );
      })}

      <div className="mz-section-title"><span>إدارة المنتجات الرقمية</span></div>
      {products.map(p => {
        const preset = PRODUCT_PRESETS[p.imageIndex];
        return (
          <div className="mz-admin-row" key={p.id}>
            <div>
              <div className="mz-tile" style={{ background: preset.gradient, marginBottom: 6 }}><preset.icon size={19} /></div>
              <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '5px 7px', display: 'flex', alignItems: 'center', gap: 4 }} onClick={() => onCycleProductImage(p.id)}><RefreshCw size={10} /> الصورة</button>
            </div>
            <div className="mz-admin-fields">
              <input className="mz-input-sm" value={p.name} onChange={e => onUpdateProduct(p.id, { name: e.target.value })} />
              <input className="mz-input-sm" type="number" value={p.cost} onChange={e => onUpdateProduct(p.id, { cost: parseInt(e.target.value) || 0 })} placeholder="التكلفة بالنقاط" />
              <label className="mz-checkbox-row"><input type="checkbox" checked={p.needsPhone} onChange={e => onUpdateProduct(p.id, { needsPhone: e.target.checked })} /> يتطلب رقم هاتف عند الاستبدال</label>
            </div>
          </div>
        );
      })}
      <button className="mz-btn-dashed" onClick={onAddProduct}><Plus size={15} /> إضافة منتج جديد</button>

      <div className="mz-section-title"><span>التحاسب الشهري مع المحلات</span></div>
      <div className="mz-card">
        {stores.map(s => {
          const tx = transactions.filter(t => t.store === s.name);
          const sales = tx.reduce((sum, t) => sum + t.amount, 0);
          const commission = sales * (s.commissionRate / 100);
          const isSettled = !!settled[s.id];
          return (
            <div className="mz-settle-row" key={s.id}>
              <div className="mz-store-icon"><Store size={17} /></div>
              <div style={{ flex: 1 }}><div className="mz-store-name">{s.name}</div><div className="mz-store-cat">{tx.length} عملية · {fmt(sales)} ل.س</div></div>
              <div style={{ textAlign: 'left' }}>
                <div style={{ fontFamily: 'Cairo', fontWeight: 700, fontSize: 12.5, color: 'var(--primary-strong)' }}>{fmt(commission)} ل.س</div>
                <button className="mz-btn-ghost" style={{ fontSize: 10, padding: '4px 8px', marginTop: 4, color: isSettled ? 'var(--ok)' : 'var(--ink)' }} onClick={() => onToggleSettled(s.id)}>{isSettled ? '✓ تم التسديد' : 'تحديد كمسدد'}</button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function NavBtn({ icon: Icon, label, active, onClick }) {
  return <button className={`mz-nav-btn ${active ? 'active' : ''}`} onClick={onClick}><Icon size={19} /><span>{label}</span></button>;
}

function MockQR() {
  const size = 9, seed = 42;
  const cells = [];
  let s = seed;
  const rand = () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
  for (let i = 0; i < size * size; i++) cells.push(rand() > 0.55);
  return (
    <svg width="150" height="150" viewBox={`0 0 ${size} ${size}`}>
      {cells.map((on, i) => {
        const x = i % size, y = Math.floor(i / size);
        const isCorner = (x < 2 && y < 2) || (x > size - 3 && y < 2) || (x < 2 && y > size - 3);
        if (isCorner) return null;
        return on ? <rect key={i} x={x} y={y} width={1} height={1} fill="#0E2A3B" /> : null;
      })}
      {[[0, 0], [size - 2, 0], [0, size - 2]].map(([cx, cy], i) => (
        <g key={i}><rect x={cx} y={cy} width={2} height={2} fill="none" stroke="#0E2A3B" strokeWidth={0.3} /><rect x={cx + 0.55} y={cy + 0.55} width={0.9} height={0.9} fill="#0E2A3B" /></g>
      ))}
    </svg>
  );
}
