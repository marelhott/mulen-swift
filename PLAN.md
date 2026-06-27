# Mulen nano — nativní macOS aplikace — PLÁN

> Stav: **plánování** (žádný kód aplikace zatím nepíšeme).
> Cíl: kompletní funkční parita s webovou Mulen nano, mínus sekce **style / model / lora**,
> plus o řád lepší **nativní macOS** design v jazyce aplikace **Fotky (Photos)**.

---

## 1. Severka designu — Fotky (Photos) v macOS

Vše se řídí pocitem z Fotek: tiché, minimální, dotažené do posledního detailu.

- **Vibrancy sidebar** vlevo (`NSVisualEffectView` / SwiftUI `Material`)
- **Unifikovaná toolbar** nahoře, minimum prvků
- **Mřížka** (`LazyVGrid`) s plynulým **zoom sliderem** (vpravo dole jako ve Fotkách)
- **Bezešvý fullscreen prohlížeč** — Space = náhled, šipky = další/předchozí
- **Inspektor** (⌘I) — metadata, „recept" generování, lineage
- **SF Symbols** všude, monochromatické
- Respekt k systémovému **light/dark**, žádné vlastní téma navíc
- Drag & drop z Finderu nativně, kontextová menu, systémové sheety

---

## 2. Rozhodnutí (zamčená)

| Téma | Rozhodnutí |
|---|---|
| Platforma | macOS (Apple Silicon), Xcode + SwiftUI |
| Distribuce | mimo App Store, **non-sandboxed**, notarizováno → výběr libovolné složky a Keychain „prostě fungují" |
| Providery v1 | **Gemini + ChatGPT** (must-have) |
| Další providery | připraveno na snadné přidání (protokol + registr), zatím neimplementovat |
| Přihlášení | **žádné** — čistě lokální, jeden uživatel na zařízení |
| Úložiště | **lokální**, ale za protokolem → cloud/sync je pozdější výměna implementace |
| Volba cesty | uživatel si vybere složku pro **nastavení i vygenerované obrázky** (i externí disk) |
| Klíče API | macOS **Keychain** |
| Komunikace s providery | přímo z aplikace (Gemini i OpenAI podporují REST z klienta) |

### Vyřazeno z webové verze
- Sekce **Style Transfer**, **Model Influence**, **Lora Influence**
- **JSON prompt editor**
- **Node/Workflow editor** (samostatný Next.js podprojekt)

---

## 3. Informační architektura (sidebar jako ve Fotkách)

```
KNIHOVNA
  ▸ Vše                  (velká mřížka všech obrázků)
  ▸ Kolekce              (rozbalovací, uživatelské „alba")
  ▸ Naposledy smazané    (koš)

NÁSTROJE
  ▸ Generovat            (hlavní „Mulen Nano" workspace)
  ▸ AI Upscaler
  ▸ Face Swap
  ▸ Reframe
  ▸ Batch
```

- **Hlavní panel** = buď mřížka (knihovna), nebo workspace nástroje.
- **Prohlížeč / inspektor** překrývají hlavní panel (jako ve Fotkách).

---

## 4. Funkce k portování (z webu, plná parita)

### Hlavní „Generovat" workspace
- Operace: **generate, edit, varianty, inpaint (mask canvas), outpaint, upscale, 3AI porovnání**
- **Grounding** (web-search k promptu) — pro Gemini
- Zdrojové / referenční obrázky (drag & drop, upload)
- Aspect ratio, rozlišení, počet obrázků
- Prompt: simple / advanced (varianty A/B/C)
- **Uložené prompty**, **prompt remix**, **prompt šablony**
- **Verze + lineage** (historie úprav obrázku, strom původu)

### Knihovna
- Mřížka s plynulým zoomem, **kolekce**, **koš**
- Detail obrázku, **porovnání** obrázků, fullscreen

### Nástroje (samostatné sekce)
- **AI Upscaler**, **Face Swap**, **Reframe**, **Batch**

### Systém
- **Nastavení**, **API klíče** (Keychain), **panel spotřeby API**
- Výběr **úložné složky**

---

## 5. Architektura modulů

```
MulenKit  (jádro — žádné UI)
  ├─ Models           GeneratedImage, GenerationRecipe, Collection, SavedPrompt, ImageVersion…
  ├─ AIProvider       protokol  ←  jádro vyměnitelnosti
  │   ├─ GeminiProvider
  │   └─ OpenAIProvider
  ├─ ProviderRegistry registr (přidat providera = 1 soubor + zápis sem)
  ├─ LibraryStore     protokol (perzistence metadat + souborů)
  │   └─ LocalLibraryStore   (SwiftData + soubory ve zvolené složce)
  ├─ KeyStore         protokol → KeychainKeyStore
  └─ StorageLocation  zvolená složka (bezpečnostní bookmark)

MulenUI  (SwiftUI)
  ├─ Sidebar, LibraryGrid, ImageViewer, Inspector
  ├─ GenerateWorkspace + MaskCanvas
  ├─ UpscalerView, FaceSwapView, ReframeView, BatchView
  └─ Settings, ApiKeys, UsagePanel

MulenApp (App target)
```

### Klíčový protokol (návrh)
```swift
protocol AIProvider {
    var id: String { get }                       // "gemini", "openai"
    var displayName: String { get }
    var capabilities: Set<ProviderCapability> { get }   // .generate, .edit, .inpaint, .grounding…
    func validate(key: APIKey) async throws -> Bool
    func run(_ request: GenerationRequest)
        -> AsyncThrowingStream<GenerationEvent, Error>   // streaming výstup
}
```
UI nikdy nezná konkrétního providera — jen protokol a registr. Přidání dalšího = nová struktura + `registry.register(...)`.

---

## 6. Data & perzistence

- **Metadata** (recepty, kolekce, verze, lineage): **SwiftData** (SQLite pod kapotou) → plynulé i u 10 000+ obrázků
- **Obrázky**: soubory ve **zvolené složce** uživatele
- **Thumbnaily**: generované přes Core Image / QuickLookThumbnailing, cachované
- **Nastavení**: v té samé zvolené složce (přenositelné, zálohovatelné)
- **Klíče**: Keychain (nikdy ne v souborech)

---

## 7. Fázový plán stavby (návrh pořadí, až schválíš)

1. **Kostra + sidebar + prázdná knihovna** — kompiluje se, spustí okno, ověříme iterační smyčku
2. **Provider vrstva** — `AIProvider`, registr, **Gemini** end-to-end (prompt → obrázek → uloží se do knihovny)
3. **Knihovna** — mřížka, zoom, detail, fullscreen, kolekce, koš
4. **Generate workspace** — operace generate/edit/varianty + zdrojové obrázky
5. **ChatGPT provider**
6. **Pokročilé operace** — inpaint (mask), outpaint, upscale, 3AI, grounding
7. **Nástroje** — Upscaler, Face Swap, Reframe, Batch
8. **Prompty** — uložené, remix, šablony; verze + lineage
9. **Systém** — nastavení, API klíče, spotřeba, výběr složky
10. **Vypilování designu** — vibrancy, animace, klávesové zkratky, inspektor

---

## 7b. STAV IMPLEMENTACE (k 26. 6. 2026)

**Skořápka & design:**
- ✅ Nativní macOS skořápka, sidebar (Nástroje / Knihovna), Nastavení (⚙︎ dole, naplocho)
- ✅ Design: světlý základ, **teal accent**, jazyk Apple Photos (PhotosSlider, kompaktní panely)
- ⏳ Vizuální dolaďování průběžně (krok 10)

**Sekce „Generovat" — 1:1 s webem (HOTOVO):**
- ✅ Generování (počet 1–5), Variace (seed×3), Interpretace (3 AI varianty promptu → obrázek)
- ✅ Skládání promptu: Styl/Merge/Object, varianty A/B/C, identita tváře, síla stylu
- ✅ Vstupní / stylové / proprietární obrázky (správné pořadí), multi-ref režim
- ✅ Gemini: safety, grounding, aspect ratio, fallback modelů; OpenAI (gpt-image-1)
- ✅ Vylepšit prompt, Uložené prompty, Šablony, Kolekce
- ✅ Výsledky: stáhnout, smazat (koš), přidat do kolekce, generovat znovu
- ✅ Knihovna (Vše), Kolekce, Naposledy smazané (koš + obnovit/vysypat)
- ✅ API klíče v Keychain, vyměnitelní provideři (registr)

**Nástroje (HOTOVO — přes Gemini edit):**
- ✅ **Reframe** — 14 perspektiv (1:1 prompty), multi-select
- ✅ **Batch** — presety Obecný/Portrét/Interiér + custom + varianty, dávka přes obrázky
- ✅ **Face Swap** — kompozit cíl+zdroj, režim Obličej/Hlava, identity-lock prompt
- ✅ **AI Upscaler** — Gemini enhance/upscale (dedikovaný upscaler = pozdější provider)

**Perzistence (HOTOVO):**
- ✅ Obrázky jako PNG soubory + library.json ve **zvolené složce**
- ✅ Nastavení → **Úložiště**: výběr složky (i externí disk), otevřít ve Finderu
- ✅ Knihovna, koš i kolekce přežijí restart

**Zatím neimplementováno (pozdější vylepšení):**
- Verze/lineage obrázků, porovnání obrázků, aspect ratio UI
- Dedikovaný upscaler/face-swap provider (replicate/fal), thumbnaily pro 10k+ obrázků
- Vizuální dolaďování designu do detailu (krok 10)

## 8. Otevřené otázky (k pozdějšímu doladění)
- Konkrétní inspirační aplikace (uživatel dodá) — pro jemné doladění nad rámec Fotek
- Klávesové zkratky (Cmd+G generovat, Space náhled… — finalizovat v kroku 10)
- Formát exportu / sdílení obrázků z knihovny
