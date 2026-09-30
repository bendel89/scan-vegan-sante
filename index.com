<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Scan Vegan">
<meta name="theme-color" content="#0a0e1a">
<title>Scan Vegan & Santé</title>
<script src="https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js"></script>
<style>
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
body{
  font-family:-apple-system,BlinkMacSystemFont,sans-serif;
  background:#0a0e1a;color:#e8ecf8;min-height:100vh;
  padding:calc(env(safe-area-inset-top) + 1rem) 1rem calc(env(safe-area-inset-bottom) + 3rem);
  font-size:16px;line-height:1.5;max-width:900px;margin:0 auto;
  -webkit-text-size-adjust:100%;
}
h1{
  text-align:center;font-size:1.5rem;margin-bottom:0.3rem;
  background:linear-gradient(135deg,#4a9eff,#7c5cff,#d94aff);
  -webkit-background-clip:text;background-clip:text;
  -webkit-text-fill-color:transparent;
}
.sub{text-align:center;font-size:0.8rem;color:#8892b0;margin-bottom:1.2rem}
.panel{background:#131829;border:1px solid #2a3350;border-radius:16px;padding:1rem;margin-bottom:1rem}
.lbl{font-size:0.72rem;color:#8892b0;text-transform:uppercase;letter-spacing:0.1em;font-weight:600;margin-bottom:0.6rem}
input[type=text]{
  width:100%;padding:1rem;border-radius:12px;border:1px solid #2a3350;
  background:#1a2036;color:#e8ecf8;font-family:inherit;font-size:17px;
  -webkit-appearance:none;
}
input:focus{outline:none;border-color:#4a9eff}
button.primary{
  width:100%;padding:1rem;border-radius:14px;border:none;
  background:linear-gradient(135deg,#4a9eff,#7c5cff);color:#fff;
  font-size:1.05rem;font-weight:600;font-family:inherit;cursor:pointer;
  margin-top:0.6rem;
}
button.primary:active{transform:scale(0.98)}
button.camera{background:linear-gradient(135deg,#2d8a4e,#6ee7a3);color:#0a0e1a}
button.stop{background:linear-gradient(135deg,#c0392b,#e07070);color:#fff}
.badge{display:inline-block;padding:0.4rem 0.9rem;border-radius:20px;font-size:0.8rem;font-weight:700;margin:0.2rem 0.2rem 0.2rem 0}
.badge.vegan{background:#2d8a4e;color:#fff}
.badge.nonvegan{background:#c0392b;color:#fff}
.badge.insect{background:#d4a017;color:#000}
.badge.health{background:#4a9eff;color:#fff}
.card{background:#131829;border:1px solid #2a3350;border-radius:16px;padding:1rem;margin-bottom:1rem}
.card.good{border-color:#2d8a4e}
.card.bad{border-color:#c0392b}
.card.warn{border-color:#d4a017}
.card h3{font-size:1rem;margin-bottom:0.5rem}
.row{display:flex;justify-content:space-between;align-items:flex-start;padding:0.6rem 0;border-bottom:1px solid #1f2740;gap:0.8rem}
.row:last-child{border-bottom:none}
.row-label{font-size:0.8rem;color:#8892b0;flex-shrink:0;font-weight:600}
.row-value{font-size:0.85rem;font-weight:600;text-align:right;flex:1;min-width:0}
.row-value.good{color:#6ee7a3}
.row-value.bad{color:#e07070}
.row-value.warn{color:#d4a017}
.loading{text-align:center;color:#8892b0;padding:2rem;font-size:0.9rem}
.spinner{width:18px;height:18px;border:2px solid rgba(74,158,255,0.3);border-top-color:#4a9eff;border-radius:50%;animation:spin 0.8s linear infinite;display:inline-block;vertical-align:middle;margin-right:0.5rem}
@keyframes spin{to{transform:rotate(360deg)}}
.error{color:#e07070;text-align:center;padding:1rem;font-size:0.9rem}
.note{font-size:0.7rem;color:#4a5578;text-align:center;margin-top:0.8rem}
.hidden{display:none!important}
#reader{border-radius:12px;overflow:hidden;background:#000}
#reader video{border-radius:12px}
</style>
</head>
<body>

<h1>🔍 Scan Vegan & Santé</h1>
<p class="sub">Analyse ton produit en un scan</p>

<div class="panel">
  <div class="lbl">📷 Code-barres du produit</div>
  <input type="text" id="barcode" placeholder="Ex : 3017620422003" inputmode="numeric" autocomplete="off" enterkeyhint="search">
  
  <button class="primary" id="btnScan">🔍 Analyser</button>
  <button class="primary camera" id="btnCamera">📷 Scanner avec la caméra</button>
  
  <div id="cameraZone" class="hidden" style="margin-top:1rem">
    <div id="reader"></div>
    <button class="primary stop" id="btnStopCamera">❌ Arrêter la caméra</button>
  </div>
</div>

<div id="result"></div>
<div class="note">Données Open Food Facts · Analyse locale</div>
<script>
// ========== 🐜 INSECTES AUTORISÉS EN SUISSE ==========
const INSECT_KEYWORDS = [
  'tenebrio molitor', 'ver de farine', 'mehlwurm', 'mealworm',
  'acheta domesticus', 'grillon', 'cricket', 'heimchen',
  'locusta migratoria', 'criquet', 'locust', 'wanderheuschrecke',
  'alphitobius diaperinus', 'petit ténébrion', 'buffalo worm',
  'insecte', 'insect', 'farine d\'insecte', 'farine d insecte',
  'poudre de larve', 'protéine d\'insecte', 'proteine d\'insecte'
];

// ========== 🌱 INGRÉDIENTS NON VEGAN ==========
const NON_VEGAN_KEYWORDS = [
  'lait', 'milk', 'beurre', 'butter', 'crème', 'creme', 'cream',
  'fromage', 'cheese', 'yaourt', 'yogurt', 'lactose', 'caséine', 'casein',
  'lactosérum', 'whey', 'petit-lait',
  'oeuf', 'œuf', 'egg', 'albumen',
  'miel', 'honey', 'cire d\'abeille', 'beeswax', 'propolis', 'gelée royale',
  'viande', 'meat', 'poulet', 'chicken', 'boeuf', 'bœuf', 'beef',
  'porc', 'pork', 'jambon', 'ham', 'agneau', 'lamb', 'veau', 'veal',
  'canard', 'duck', 'dinde', 'turkey', 'gibier',
  'poisson', 'fish', 'thon', 'tuna', 'saumon', 'salmon', 'cabillaud',
  'crevette', 'shrimp', 'crabe', 'crab', 'homard', 'lobster',
  'moule', 'mussel', 'huître', 'huitre', 'oyster', 'anchois', 'anchovy',
  'gélatine', 'gelatin', 'graisse animale', 'animal fat', 'saindoux',
  'lard', 'suif', 'bouillon', 'broth',
  'e120', 'e904', 'e901', 'e920', 'e921',
  'cochenille', 'cochineal', 'carmine', 'shellac', 'lécithine',
  'lecitin', 'e441', 'e542', 'e913', 'e1105', 'lysozyme'
];

// ========== 🇨🇭 ADDITIFS CONTROVERSÉS ==========
const HEALTH_WARNINGS = {
  'e249': { level: 'danger', msg: 'Nitrite de potassium — composés cancérigènes' },
  'e250': { level: 'danger', msg: 'Nitrite de sodium — composés cancérigènes' },
  'e251': { level: 'danger', msg: 'Nitrate de sodium — précurseur de nitrites' },
  'e252': { level: 'danger', msg: 'Nitrate de potassium — précurseur de nitrites' },
  'e202': { level: 'warn', msg: 'Sorbate de potassium — risque d\'hypertension' },
  'e150a': { level: 'warn', msg: 'Colorant caramel — associé au diabète type 2' },
  'e150b': { level: 'warn', msg: 'Caramel sulfite — controversé' },
  'e150c': { level: 'warn', msg: 'Caramel ammoniacal — controversé' },
  'e150d': { level: 'warn', msg: 'Caramel sulfite-ammoniacal — controversé' },
  'e120': { level: 'danger', msg: 'Rouge cochenille — extrait d\'insectes' },
  'e904': { level: 'danger', msg: 'Shellac — résine d\'insecte' },
  'e901': { level: 'warn', msg: 'Cire d\'abeille — non végétalien' },
  'e621': { level: 'warn', msg: 'Glutamate monosodique — sensibilité possible' },
  'e951': { level: 'warn', msg: 'Aspartame — sujet à débat' },
  'e220': { level: 'warn', msg: 'Anhydride sulfureux — allergène' },
  'e221': { level: 'warn', msg: 'Sulfite de sodium — allergène' },
  'e222': { level: 'warn', msg: 'Sulfite acide de sodium — allergène' },
  'e223': { level: 'warn', msg: 'Disulfite de sodium — allergène' },
  'e224': { level: 'warn', msg: 'Disulfite de potassium — allergène' },
  'e226': { level: 'warn', msg: 'Sulfite de calcium — allergène' },
  'e227': { level: 'warn', msg: 'Sulfite acide de calcium — allergène' },
  'e228': { level: 'warn', msg: 'Sulfite acide de potassium — allergène' },
  'e102': { level: 'warn', msg: 'Tartrazine — colorant azoïque controversé' },
  'e104': { level: 'warn', msg: 'Jaune de quinoléine — colorant controversé' },
  'e110': { level: 'warn', msg: 'Jaune orangé S — colorant azoïque' },
  'e122': { level: 'warn', msg: 'Azorubine — colorant azoïque' },
  'e124': { level: 'warn', msg: 'Ponceau 4R — colorant azoïque' },
  'e129': { level: 'warn', msg: 'Rouge allura — colorant azoïque' },
  'e171': { level: 'danger', msg: 'Dioxyde de titane — interdit dans l\'UE depuis 2022' }
};

// ========== 🔍 DÉTECTIONS ==========
function detectInsects(texte) {
  if (!texte) return [];
  const t = texte.toLowerCase();
  return [...new Set(INSECT_KEYWORDS.filter(k => t.includes(k)))];
}

function detectNonVegan(texte) {
  if (!texte) return [];
  const t = texte.toLowerCase();
  return [...new Set(NON_VEGAN_KEYWORDS.filter(k => t.includes(k)))];
}

function detectHealthWarnings(additifs) {
  if (!additifs) return [];
  const t = additifs.toLowerCase();
  const trouves = [];
  for (const [code, info] of Object.entries(HEALTH_WARNINGS)) {
    if (t.includes(code) || t.includes('en:' + code)) {
      trouves.push({ code: code.toUpperCase(), ...info });
    }
  }
  return trouves;
}

// ========== 🎯 ANALYSE PRINCIPALE ==========
async function analyserCodeBarres(code) {
  const zone = document.getElementById('result');
  zone.innerHTML = '<div class="loading"><span class="spinner"></span>Recherche en cours…</div>';

  try {
    const url = `https://world.openfoodfacts.org/api/v2/product/${code}.json?fields=product_name,ingredients_text,ingredients_text_fr,additives_tags,allergens_tags,nutriscore_grade,brands,categories`;
    const reponse = await fetch(url);
    const data = await reponse.json();

    const ok = data.status === 1 || data.status === 'success' || (data.product && data.product.product_name);
    if (!ok || !data.product) {
      zone.innerHTML = '<div class="error">❌ Produit introuvable dans Open Food Facts.<br><br>Essaie un autre code-barres.</div>';
      return;
    }

    const p = data.product;
    const ingredients = p.ingredients_text_fr || p.ingredients_text || '';
    const additifsListe = p.additives_tags || [];
    const additifsTexte = additifsListe.join(' ');
    const nom = p.product_name || 'Produit sans nom';
    const marque = p.brands || '';
    const nutriscore = p.nutriscore_grade ? p.nutriscore_grade.toUpperCase() : null;

    const insectes = detectInsects(ingredients);
    const nonVeganIngredients = detectNonVegan(ingredients);
    const nonVeganAdditifs = additifsListe.filter(a =>
      a.includes('e120') || a.includes('e904') || a.includes('e901') ||
      a.includes('e920') || a.includes('e921') || a.includes('e1105')
    );
    const tousNonVegan = [...new Set([...nonVeganIngredients, ...nonVeganAdditifs])];
    const alertesSante = detectHealthWarnings(additifsTexte);

    let html = '';

    html += `<div class="card">
      <h3>${marque ? marque + ' — ' : ''}${nom}</h3>
      <div style="font-size:0.78rem;color:#8892b0;margin-top:0.3rem">Code-barres : ${code}</div>
    </div>`;

    const estVegan = tousNonVegan.length === 0;
    html += `<div class="card ${estVegan ? 'good' : 'bad'}">
      <div class="lbl">🌱 Analyse Vegan</div>
      <span class="badge ${estVegan ? 'vegan' : 'nonvegan'}">
        ${estVegan ? '✅ VEGAN' : '❌ NON VEGAN'}
      </span>
      ${!estVegan ? `<div style="margin-top:0.7rem;font-size:0.82rem;color:#e07070">
        <strong>Détecté :</strong> ${tousNonVegan.slice(0, 8).join(', ')}${tousNonVegan.length > 8 ? '…' : ''}
      </div>` : ''}
    </div>`;

    html += `<div class="card ${insectes.length > 0 ? 'warn' : 'good'}">
      <div class="lbl">🐜 Alerte Insectes</div>
      <span class="badge ${insectes.length > 0 ? 'insect' : 'vegan'}">
        ${insectes.length > 0 ? '⚠️ INSECTES DÉTECTÉS' : '✅ Aucun insecte'}
      </span>
      ${insectes.length > 0 ? `<div style="margin-top:0.7rem;font-size:0.82rem;color:#d4a017">
        <strong>Détecté :</strong> ${insectes.join(', ')}
      </div>` : ''}
      <div style="margin-top:0.6rem;font-size:0.7rem;color:#8892b0">
        Recherche : Tenebrio molitor · Acheta domesticus · Locusta migratoria · Alphitobius diaperinus
      </div>
    </div>`;

    const aDanger = alertesSante.some(a => a.level === 'danger');
    const aWarn = alertesSante.some(a => a.level === 'warn');
    html += `<div class="card ${aDanger ? 'bad' : aWarn ? 'warn' : 'good'}">
      <div class="lbl">🇨🇭 Santé / Additifs</div>`;
    if (alertesSante.length === 0) {
      html += `<span class="badge health">✅ Aucun additif signalé</span>`;
    } else {
      alertesSante.forEach(a => {
        html += `<div class="row">
          <span class="row-label">${a.code}</span>
          <span class="row-value ${a.level === 'danger' ? 'bad' : 'warn'}">${a.msg}</span>
        </div>`;
      });
    }
    html += `</div>`;

    if (additifsListe.length > 0) {
      const codes = additifsListe.map(a => a.replace('en:', '').toUpperCase());
      html += `<div class="card">
        <div class="lbl">🧪 Tous les additifs (${codes.length})</div>
        <div style="font-size:0.8rem;color:#8892b0;line-height:1.8">${codes.join(' · ')}</div>
      </div>`;
    }

    if (nutriscore) {
      const couleurs = { A: '#2d8a4e', B: '#6ee7a3', C: '#d4a017', D: '#e07070', E: '#c0392b' };
      html += `<div class="card">
        <div class="lbl">📊 Nutri-Score</div>
        <span class="badge" style="background:${couleurs[nutriscore] || '#4a9eff'};color:#fff;font-size:1.2rem;padding:0.6rem 1.4rem">${nutriscore}</span>
      </div>`;
    }

    zone.innerHTML = html;

  } catch (e) {
    zone.innerHTML = `<div class="error">❌ Erreur réseau : ${e.message}<br><br>Vérifie ta connexion internet.</div>`;
  }
}

// ========== 🎬 ÉVÉNEMENTS ==========
document.getElementById('btnScan').addEventListener('click', () => {
  const code = document.getElementById('barcode').value.trim();
  if (code) analyserCodeBarres(code);
});

document.getElementById('barcode').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    e.preventDefault();
    const code = document.getElementById('barcode').value.trim();
    if (code) analyserCodeBarres(code);
  }
});

// ========== 📷 SCAN CAMÉRA ==========
let html5QrCode = null;

async function demarrerCamera() {
  const zone = document.getElementById('cameraZone');
  zone.classList.remove('hidden');

  if (!html5QrCode) {
    html5QrCode = new Html5Qrcode("reader");
  }

  try {
    await html5QrCode.start(
      { facingMode: "environment" },
      {
        fps: 10,
        qrbox: { width: 280, height: 180 },
        aspectRatio: 1.0,
        formatsToSupport: [
          Html5QrcodeSupportedFormats.EAN_13,
          Html5QrcodeSupportedFormats.EAN_8,
          Html5QrcodeSupportedFormats.UPC_A,
          Html5QrcodeSupportedFormats.UPC_E,
          Html5QrcodeSupportedFormats.CODE_128,
          Html5QrcodeSupportedFormats.CODE_39,
          Html5QrcodeSupportedFormats.ITF,
          Html5QrcodeSupportedFormats.QR_CODE
        ]
      },
      (texteDecode) => {
        document.getElementById('barcode').value = texteDecode;
        arreterCamera();
        analyserCodeBarres(texteDecode);
      },
      (erreur) => { /* ignoré */ }
    );
  } catch (err) {
    alert("❌ Impossible d'accéder à la caméra.\n\nVérifie que tu as autorisé la caméra dans Safari.\n\nDétail : " + err.message);
    zone.classList.add('hidden');
  }
}

async function arreterCamera() {
  if (html5QrCode) {
    try {
      await html5QrCode.stop();
      html5QrCode.clear();
    } catch (e) { /* déjà arrêtée */ }
  }
  document.getElementById('cameraZone').classList.add('hidden');
}

document.getElementById('btnCamera').addEventListener('click', demarrerCamera);
document.getElementById('btnStopCamera').addEventListener('click', arreterCamera);

</script>
</body>
</html>
