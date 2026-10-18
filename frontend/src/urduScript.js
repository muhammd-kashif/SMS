const words = {
  a: 'اے', b: 'بی', c: 'سی', d: 'ڈی', e: 'ای', f: 'ایف', g: 'جی', h: 'ایچ',
  i: 'آئی', j: 'جے', k: 'کے', l: 'ایل', m: 'ایم', n: 'این', o: 'او', p: 'پی',
  q: 'کیو', r: 'آر', s: 'ایس', t: 'ٹی', u: 'یو', v: 'وی', w: 'ڈبلیو', x: 'ایکس', y: 'وائی', z: 'زیڈ',
  admin: 'ایڈمن', ahmed: 'احمد', ayesha: 'عائشہ', fatima: 'فاطمہ', maryam: 'مریم', hina: 'حنا',
  sana: 'ثنا', zainab: 'زینب', hira: 'حرا', iqra: 'اقراء', laiba: 'لائبہ', mahnoor: 'ماہ نور',
  anaya: 'انایہ', noor: 'نور', rabia: 'رابعہ', khadija: 'خدیجہ', amna: 'آمنہ', esha: 'عشا',
  marium: 'مریم', aleena: 'علینہ', bushra: 'بشریٰ', nimra: 'نمرہ', sidra: 'سدرہ', mehwish: 'مہوش',
  areeba: 'اریبہ', hadia: 'ہادیہ', inaya: 'انایہ', alishba: 'علیشبہ', minahil: 'مناہل', hafsa: 'حفصہ',
  rida: 'رِدا', sara: 'سارہ', muhammad: 'محمد', ali: 'علی', hassan: 'حسن', bilal: 'بلال',
  usman: 'عثمان', hamza: 'حمزہ', omar: 'عمر', ibrahim: 'ابراہیم', zain: 'زین', rayyan: 'ریان',
  abdullah: 'عبداللہ', hussain: 'حسین', imran: 'عمران', farhan: 'فرحان', saad: 'سعد', talha: 'طلحہ',
  danish: 'دانش', fahad: 'فہد', kamran: 'کامران', adeel: 'عدیل', adnan: 'عدنان', waqas: 'وقاص', shahzaib: 'شہزیب',
  haris: 'حارث', ayaan: 'ایان', rohan: 'روہن', sameer: 'سمیر', noman: 'نعمان', junaid: 'جنید',
  arsalan: 'ارسلان', khan: 'خان', malik: 'ملک', raza: 'رضا', shah: 'شاہ', butt: 'بٹ',
  chaudhry: 'چوہدری', qureshi: 'قریشی', siddiqui: 'صدیقی', sheikh: 'شیخ', dar: 'ڈار', mirza: 'مرزا',
  baig: 'بیگ', abbasi: 'عباسی', awan: 'اعوان', javed: 'جاوید', iqbal: 'اقبال', akhtar: 'اختر',
  farooq: 'فاروق', tariq: 'طارق', anwar: 'انور', khalid: 'خالد', mehmood: 'محمود', hashmi: 'ہاشمی',
  naqvi: 'نقوی', rizvi: 'رضوی', gill: 'گل', cheema: 'چیمہ', bhatti: 'بھٹی', lone: 'لون',
  saima: 'صائمہ', nadia: 'نادیہ', mrs: 'مسز', house: 'مکان', street: 'گلی', lahore: 'لاہور',
  town: 'ٹاؤن', phase: 'فیز', model: 'ماڈل', gulberg: 'گلبرگ', johar: 'جوہر', dha: 'ڈی ایچ اے',
  wapda: 'واپڈا', garden: 'گارڈن', faisal: 'فیصل', valencia: 'ویلنسیا', allama: 'علامہ',
  roll: 'رول', update: 'تبدیل', register: 'رجسٹر', saved: 'محفوظ', scans: 'اسکین', sync: 'بھیجیں',
  cms: 'سی ایم ایس', sc: 'ایس سی',
};

const sounds = [
  ['kh', 'خ'], ['gh', 'غ'], ['sh', 'ش'], ['ch', 'چ'], ['th', 'تھ'], ['ph', 'پھ'],
  ['bh', 'بھ'], ['dh', 'دھ'], ['zh', 'ژ'], ['aa', 'ا'], ['ee', 'ی'], ['oo', 'و'],
  ['ai', 'ے'], ['au', 'و'], ['a', 'ا'], ['b', 'ب'], ['c', 'ک'], ['d', 'د'], ['e', 'ی'],
  ['f', 'ف'], ['g', 'گ'], ['h', 'ہ'], ['i', 'ی'], ['j', 'ج'], ['k', 'ک'], ['l', 'ل'],
  ['m', 'م'], ['n', 'ن'], ['o', 'و'], ['p', 'پ'], ['q', 'ق'], ['r', 'ر'], ['s', 'س'],
  ['t', 'ت'], ['u', 'و'], ['v', 'و'], ['w', 'و'], ['x', 'کس'], ['y', 'ی'], ['z', 'ز'],
];

function phonetic(word) {
  const lower = word.toLowerCase();
  let out = '';
  let i = 0;
  while (i < lower.length) {
    if (i > 0 && lower[i] === lower[i - 1] && !'aeiou'.includes(lower[i])) {
      i += 1;
      continue;
    }
    const pair = sounds.find(([en]) => lower.startsWith(en, i));
    if (!pair) {
      i += 1;
      continue;
    }
    out += pair[1];
    i += pair[0].length;
  }
  return out || word;
}

function spell(word) {
  const key = word.toLowerCase().replace(/[.'-]+$/g, '');
  return words[key] || phonetic(key);
}

export function toUrduScript(text) {
  if (!/[A-Za-z]/.test(text)) return text;
  return text.split(/(\s+)/).map((part) => {
    if (!/[A-Za-z]/.test(part) || /@|https?:/i.test(part) || /^[A-Za-z]{2,}-\d/.test(part)) return part;
    return part.replace(/[A-Za-z]+/g, spell);
  }).join('');
}
