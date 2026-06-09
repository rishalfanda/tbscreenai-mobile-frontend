# TBScreen – Flutter UI Prompt for Trae AI

## Project Overview
Build the **TBScreen** Flutter application — a medical AI tablet app for tuberculosis (TB) diagnosis using AI-powered chest X-ray analysis. This is a **UI-only development phase**; no backend integration yet. All data is mocked/static. Testing target is **Windows desktop** (flutter run -d windows) while the final deployment target is **Android tablet (landscape, 10–12 inch)**.

---

## Development Constraints

- **Framework**: Flutter (Dart)
- **Target runtime for testing**: Windows desktop (`flutter run -d windows`)
- **Final deployment target**: Android tablet, landscape orientation, 10–12 inch screen
- **Phase**: UI only — no real API calls, no database, use mock/hardcoded data
- **Design system**: Material Design 3 (`useMaterial3: true`)
- **State management**: Use `StatefulWidget` or `Provider` — keep it simple, no over-engineering
- **Navigation**: Use `go_router` package for named route navigation

---

## Flutter Project Structure

```
lib/
├── main.dart
├── app.dart                  # MaterialApp + GoRouter setup
├── theme/
│   └── app_theme.dart        # ColorScheme, TextTheme, ThemeData
├── screens/
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── diagnosis_screen.dart
│   ├── camera_screen.dart
│   ├── result_screen.dart
│   ├── patients_screen.dart
│   ├── dataset_screen.dart
│   └── account_screen.dart
├── widgets/
│   ├── nav_rail.dart         # Custom Navigation Rail
│   ├── stat_card.dart
│   ├── patient_list_item.dart
│   └── (other reusable widgets)
└── models/
    └── diagnosis_data.dart   # DiagnosisData model class
```

---

## Theme & Design System

### pubspec.yaml dependencies (minimum)
```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0
  provider: ^6.0.0
```

### ColorScheme (app_theme.dart)
```dart
const primary = Color(0xFF4FC3F7);         // Light Blue 400
const primaryDark = Color(0xFF0288D1);     // Light Blue 700
const secondary = Color(0xFF1E3A5F);       // Dark Navy
const success = Color(0xFF22C55E);         // Green 500
const warning = Color(0xFFF59E0B);         // Amber 500
const error = Color(0xFFEF4444);           // Red 500
const background = Color(0xFFF9FAFB);      // Gray 50
const surface = Color(0xFFFFFFFF);         // White
const textPrimary = Color(0xFF111827);     // Gray 900
const textSecondary = Color(0xFF6B7280);   // Gray 500
```

### Spacing System (use as constants)
```dart
const double sp4 = 4;
const double sp8 = 8;
const double sp12 = 12;
const double sp16 = 16;
const double sp24 = 24;
const double sp32 = 32;
const double sp48 = 48;
// Card padding: 24.0
// Page padding: 32.0
```

### Border Radius
```dart
const double radiusCard = 16;     // Most cards
const double radiusInput = 12;    // Form inputs
const double radiusLarge = 24;    // Login card
```

### Elevation
```dart
// Cards: elevation 2 (shadow-md equivalent)
// Elevated cards: elevation 4 (shadow-lg)
// Floating: elevation 8 (shadow-xl)
```

### Touch Targets
- Minimum touch target: **48×48 logical pixels** (use `SizedBox` or `ConstrainedBox` for enforcement)
- Primary buttons: minimum height **56px** (`py-4` equivalent)
- Form inputs: minimum height **48px** (`py-3` equivalent)

---

## Global Layout Structure

### Navigation Rail
- Implement as a **custom widget** (`NavRail`) on the left side of the main scaffold
- **Width**: 80px
- **Background**: `Color(0xFF1E3A5F)` (Dark Navy)
- **Position**: Fixed left via `Row` + `NavigationRail` or custom `Column`

```dart
// Nav items:
// 1. Dashboard  → Icons.dashboard_outlined / dashboard
// 2. Patients   → Icons.people_outline / people
// 3. Diagnose   → Icons.stethoscope (use medical_services or custom)
// 4. Dataset    → Icons.storage_outlined
// 5. Account    → Icons.account_circle_outlined

// Logo area: 48×48, rounded 12, gradient from primary to primaryDark
// Nav buttons: 56×56, active = bg primary with white icon, inactive = text #B0C4DE
// Icon size: 20px
// Label: 9px, below icon
// Hover (desktop): bg Color(0xFF2D4A6A)
```

Use `InkWell` + `AnimatedContainer` for hover/active states on desktop.

### Main Layout Scaffold (screens with nav)
```dart
Scaffold(
  body: Row(
    children: [
      NavRail(currentIndex: ..., onTap: ...),
      Expanded(
        child: Container(
          color: Color(0xFFF9FAFB),
          child: // screen content
        ),
      ),
    ],
  ),
)
```

---

## Screen Specifications

---

### 1. Login Screen (`login_screen.dart`)

**No NavRail on this screen.**

```
Layout:
- Full screen, gradient background: Color(0xFF1E3A5F) → Color(0xFF0D1B2A)
- Centered white Card: maxWidth 400, borderRadius 24, elevation 8

Logo:
- 80×80, borderRadius 16
- Gradient: primary → primaryDark
- "TB" text, white, bold, fontSize 28

Title:
- "TBScreen" – fontSize 22, fontWeight bold, color secondary
- Subtitle: "AI-Powered TB Diagnosis" – fontSize 13, color textSecondary

Form:
- Email field: prefix Icon(Icons.mail_outline), border radius 12, border 2px gray-200
  focusedBorder: borderColor primary
- Password field: prefix Icon(Icons.lock_outline), same styling, obscureText: true

Submit button:
- Full width, height 56
- Gradient decoration: primary → primaryDark
- "Sign In" text, white, fontWeight medium
- onTap: navigate to /dashboard (mock, no real auth)
```

---

### 2. Dashboard Screen (`dashboard_screen.dart`)

```
Max content width: 1600px (use Center + ConstrainedBox)
Padding: EdgeInsets.all(32)

Header Row:
- Left: Column("Dashboard" bold 28px, "Welcome back, Dr. Ahmad" gray 14px)
- Right: ElevatedButton.icon(Icons.add, "New Diagnosis") gradient style → navigate /diagnosis

Statistics Row (4 cards, use Wrap or Row with Expanded):
Each StatCard widget:
  - bg white, borderRadius 16, elevation 2, padding 24
  - Icon 48×48 container with colored background, rounded 12
  - Label: fontSize 13, textSecondary
  - Value: fontSize 28, fontWeight bold
  - Change badge: "+X%" green or red

Cards:
  1. Total Patients    – Icons.people,          bg blue-100
  2. Total Diagnoses   – Icons.monitor_heart,   bg purple-100
  3. Positive Cases    – Icons.warning_amber,   bg red-100
  4. Detection Rate    – Icons.trending_up,     bg green-100

Body Row (use Row with flex):
  Left (flex 2): Recent Activity Card
    - ListTiles with leading CircleAvatar (gradient, initials)
    - Patient name + timestamp
    - Trailing: result badge (Positive=red, Negative=green chip) + confidence %
    - Hover: bg gray-50 (use MouseRegion on desktop)

  Right (flex 1): Column(
    - Quick Actions Card
        gradient from primary to primaryDark, borderRadius 16
        two buttons: "New Diagnosis" → /diagnosis, "View Patients" → /patients
        white text on semi-transparent white container
    - System Status Card (margin top 16)
        "AI Model: Active" green dot
        "Database: Connected" green dot
        "Storage: 68%" LinearProgressIndicator
  )
```

---

### 3. Diagnosis Screen (`diagnosis_screen.dart`) — MOST CRITICAL

```
Max width: 1600px
Layout: Row(
  Expanded(flex:2, child: left form sections),
  SizedBox(width:16),
  SizedBox(width:320, child: image panel sticky),
)

Use SingleChildScrollView for left form side.
All sections are Cards(borderRadius:16, elevation:2, padding:24).

--- Section 1: Basic Information ---
Section title: "Basic Information"
GridView or Wrap of TextFormFields:
  - Name/Initial/Nickname  (full row)
  - Gender (DropdownButtonFormField: Male/Female/Other)
  - Age (number input)
  - Height cm (number input)
  - Weight kg
All inputs: borderRadius 12, border 2px gray-200, focusedBorder primary

--- Section 2: Symptoms ---
Section title: "Symptoms"
GridView 3-column of CheckboxListTile or custom checkbox items:
  Fever, Cough, Shortness of Breath, Fatigue,
  Hemoptysis, Night Sweats, Loss of Appetite,
  Weight Loss, Chest Pain, Other
Checkbox color: primary; activeColor: primary

--- Section 3: Clinical Background ---
Three DropdownButtonFormFields in a Row:
  1. Comorbidity (None / Diabetes / HIV-AIDS / COPD / Other)
  2. Smoking Status (Never / Former / Current)
  3. TB Contact History (None / Household / Workplace / Other)

--- Section 4: Pediatric TB (Conditional) ---
Show ONLY if age < 18:
  Container with bg amber-50, border 2px amber-200, borderRadius 12
  Title in amber-900 color
  TextFormField: "Pediatric TB Scoring (0–10)"
  Helper text in amber-700

--- Section 5: Environment ---
Two DropdownButtonFormFields in Row:
  1. Presence of Windows (Yes / No)
  2. Direct Sunlight Exposure (Good / Moderate / Poor)

--- Section 6: Bacteriology ---
Three radio groups in Column:
  1. Expel Sputum (BTA): BTA Positive / BTA Negative
  2. Culture: Positive / Negative
  3. Xpert MTB/RIF or NAAT: Positive / Negative
Use Row of Radio<String> + Text labels, spacing gap 16

--- Section 7: Other Tests ---
Radio group:
  IGRA: Positive / Negative / Other

--- Section 8: TB Status ---
Three DropdownButtonFormFields in Row:
  1. History of TB (No History / Previously Treated / Ongoing Treatment)
  2. TB Status (New Case / Relapse / Follow-up)
  3. Model Type (Standard / Enhanced / Research)

--- Section 9: Image Input Panel (Right, sticky/fixed) ---
Card(borderRadius:16, elevation:2, padding:24)
  
  Image preview area (aspect ratio 1:1):
    - If empty: dotted border, centered upload icon + "Upload or Capture X-ray"
    - If image: Image.file / Image.memory with Stack + close button (×) top-right

  Button 1: "Upload X-ray Image"
    - OutlinedButton, full width, border primary, text primary
    - Icons.upload_file
    - onTap: file picker (mock: set a placeholder image)

  Button 2: "Capture from Camera"
    - ElevatedButton, full width, gradient primary→primaryDark
    - Icons.camera_alt
    - onTap: navigate to /camera

  Button 3: "Run AI Diagnosis"
    - ElevatedButton, full width, height 56, gradient green-500→green-600
    - Icons.play_arrow / Icons.analytics
    - Disabled if no image (style: gray)
    - onTap: show loading (CircularProgressIndicator / animated button state)
      then after 3 seconds navigate to /result
```

---

### 4. Camera Screen (`camera_screen.dart`)

**Full-screen, no NavRail.**

```
Scaffold(
  backgroundColor: Colors.black,
  body: Stack(
    children: [
      // Full-screen mock camera preview (use black Container with placeholder text
      //   or actual camera_controller if package available — mock is fine for UI phase)
      
      // Top-left close button
      Positioned(top:24, left:24,
        child: InkWell(
          child: Container(
            w:48, h:48, decoration: circle, color: Colors.black54,
            child: Icon(Icons.close, color:white)
          ),
          onTap: () => context.pop()
        )
      ),
      
      // Center overlay guide
      Center(
        child: Container(
          maxWidth: 600, aspectRatio: 4/3,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.5), width:4),
            borderRadius: 24,
          ),
          child: // Corner bracket decorations in Color(0xFF4FC3F7)
                 // Text: "Position X-ray within frame"
        )
      ),

      // Bottom controls
      Positioned(bottom:0, left:0, right:0,
        child: Container(
          padding: EdgeInsets.symmetric(vertical:32, horizontal:48),
          decoration: BoxDecoration(gradient: black/80 fade),
          child: Row(mainAxisAlignment: spaceBetween, children:[
            // Flash toggle (56×56 circle)
            // Capture button (80×80, white outer, primary inner circle)
            // Camera switch (56×56)
          ])
        )
      ),
    ]
  )
)

// After capture: show preview mode
//   "Retake" button + "Confirm" gradient green button
//   Confirm: pop with image data → diagnosis screen updates image
```

---

### 5. Result Screen (`result_screen.dart`)

```
Max width: 1600px, padding 32

Header Row:
  - Title "Diagnosis Result"
  - Action buttons: Save, Export PDF, Print
    OutlinedButton each: borderRadius 12, border gray-200
    hover: border primary, text primary

Layout: Row(
  Expanded(flex:2, left column with details),
  SizedBox(width:320, right column with result card),
)

Left column:
  1. X-ray Image Card (aspect ratio 16:9, bg gray-900, image object-contain)
  2. Patient Summary Card
       GridView 3-col: Name, Gender, Age, Height, Weight, BMI (calculated)
       Each field: label (gray 13px) + value (medium weight)
  3. Clinical Data Card
       Symptoms as blue Chip widgets (Wrap)
       Comorbidity, Smoking Status, TB Contact, BTA Status, Culture Status

Right column:
  1. Diagnosis Result Card (gradient)
       Positive result: gradient red-500 → red-600
       Negative result: gradient green-500 → green-600
       - Icon 64px: AlertCircle (positive) or CheckCircle (negative)
       - Title "TB Detected" or "Normal", white bold 22px
       - Confidence score: bg white/20, text 40px bold, label "AI Confidence"

  2. Recommendation Card
       Positive: red alert box with checklist steps
       Negative: green box with monitoring recommendations
       
  3. Analysis Details Card
       - Analysis Date
       - Model Version: "TBScreen v2.1.0"
       - Processing Time: "2.8s"

  4. "New Diagnosis" button
       Full width, gradient primary, navigate /diagnosis
```

---

### 6. Patients Screen (`patients_screen.dart`)

```
Layout: Row(
  SizedBox(width: 420, child: patient list panel),
  Expanded(child: patient detail panel),
)

Left panel (list):
  - Header: "Patients" title + search TextField with Icons.search prefix
  - ListView of patient items:
      ListTile / custom widget:
        leading: CircleAvatar gradient with initials
        title: patient name
        subtitle: "Age • Gender"
        trailing: Row(status Chip + Icons.chevron_right)
        selected: bg blue-50, left border 4px primary
        onTap: update selectedPatient state

Right panel (detail):
  If no selection:
    Center(Column(Icon(Icons.person_outline, size:64, color:gray), Text("Select a patient to view details")))
  
  If selected:
    SingleChildScrollView with:
    1. Patient Header Card
         CircleAvatar 80px gradient + name + Patient ID "#TB000001" + status chip
    2. Stats Grid (4 cols): Age, Gender, Last Visit, Confidence
         each in rounded container bg gray-50, padding 16
    3. Latest Diagnosis Card
         aspect-video image placeholder + date with Icons.calendar_today
    4. Medical History Card
         timeline list items with icons (previous screenings, registration date)

Mock data: 8 sample patients (hardcoded list in patients_screen.dart or models/)
```

---

### 7. Dataset Screen (`dataset_screen.dart`)

```
Max width: 1600px, padding 32

Header Row: "Dataset Management" title + "Upload" gradient button

Search & Filter Row:
  TextField search + DropdownButton filter options

Data Table (use DataTable or custom):
  Columns: Date, Patient ID, Image (thumbnail), Status, Actions
  Rows: 10 mock entries
  Pagination: simple prev/next buttons, "Showing X–Y of Z"

Style:
  Table in Card(borderRadius:16, elevation:2)
  Header row: bg gray-50, bold text
  Row hover: bg gray-50
  Status chips: Positive=red, Negative=green
  Actions: IconButton (eye, download, delete)
```

---

### 8. Account Screen (`account_screen.dart`)

```
Max width: 1200px, padding 32

1. Profile Card
   Row: CircleAvatar 96px gradient + Column(name, email, role) + "Edit Profile" OutlinedButton
   Stats grid (3 cols): Total Diagnoses, Accuracy Rate, Positive Cases
   Each stat: rounded-12 bg gray-50 padding 16

2. Account Information Card
   Form GridView 2-col:
     Full Name, Email, Specialization (DropdownButton), Institution
   All inputs same style as Diagnosis screen

3. Security Card
   ListTile 1: Key icon (blue-100 circle) + "Change Password" + subtitle + ChevronRight
   ListTile 2: Shield icon (purple-100 circle) + "Two-Factor Authentication" + "Enabled" green chip

4. Notifications Card
   SwitchListTile: "Diagnosis Completed" (bell icon orange-100)
   SwitchListTile: "New Patient Registration" (person icon green-100)

5. Danger Zone
   ElevatedButton full width, height 56
   bg red-500, "Sign Out", Icons.logout
   onTap: navigate to /login (mock)
```

---

## Navigation & Routing (go_router)

```dart
// Routes:
// /login           → LoginScreen        (no nav rail)
// /dashboard       → DashboardScreen    (with nav rail, index 0)
// /diagnosis       → DiagnosisScreen    (with nav rail, index 2)
// /camera          → CameraScreen       (full screen, no nav rail)
// /result          → ResultScreen       (with nav rail)
// /patients        → PatientsScreen     (with nav rail, index 1)
// /dataset         → DatasetScreen      (with nav rail, index 3)
// /account         → AccountScreen      (with nav rail, index 4)

// Initial route: /login → after tap "Sign In" → /dashboard
```

Use a `ShellRoute` in go_router for routes that share the NavRail, so the NavRail persists across navigation without rebuild.

---

## Data Model

```dart
// models/diagnosis_data.dart

class DiagnosisData {
  String name;
  String gender;           // 'male' | 'female' | 'other'
  int age;
  double height;
  double weight;

  // Symptoms
  bool fever, cough, shortnessOfBreath, fatigue;
  bool hemoptysis, nightSweats, lossOfAppetite;
  bool weightLoss, chestPain, other;

  // Clinical
  String comorbidity;
  String smokingStatus;
  String tbContact;

  // Pediatric (conditional, age < 18)
  int? pediatricScore;

  // Environment
  String windows;
  String sunlight;

  // Bacteriology
  String btaStatus;
  String cultureStatus;
  String xpertStatus;

  // Other Tests
  String igraStatus;

  // TB Status
  String tbHistory;
  String tbStatus;
  String modelType;

  // Image
  Uint8List? imageBytes;   // captured/uploaded image
}
```

---

## Interaction & Animation Guidelines

```
Hover effects (desktop Windows):
  Use MouseRegion + AnimatedContainer
  Cards: slight elevation increase on hover
  Buttons: shadow increase

Active/pressed states:
  Use GestureDetector or InkWell
  Scale: 0.98 on tap down (Transform.scale)

Loading states:
  CircularProgressIndicator with primary color
  Disable button + show spinner inside button

Transitions:
  PageTransition: fade or slide (go_router transition builder)
  Duration: 200–300ms

Feedback:
  SnackBar for success/error messages
  LinearProgressIndicator for processing
```

---

## Windows Desktop Adaptations (Testing Only)

- Use `LayoutBuilder` with breakpoints: if width > 1024 → full tablet layout, else collapse
- Mouse hover states via `MouseRegion` for all interactive elements
- Scrollbar visible on desktop (`ScrollbarTheme`)
- Window minimum size: 1024×768 (set in `windows/runner/main.cpp` or `window_manager` package)
- No camera hardware required for UI phase — mock camera screen with static image

---

## Mock Data Guidelines

```dart
// Use hardcoded lists for:
// - 8 sample patients (name, age, gender, status, confidence, date)
// - Dashboard stats (totalPatients: 247, totalDiagnoses: 1842, positiveCases: 89, detectionRate: 94.2%)
// - Dataset rows (10 entries)
// - Result screen: randomize between Positive/Negative with 75–98% confidence

// No API calls, no http package, no async data fetching
// Simulate AI processing with Future.delayed(Duration(seconds: 3))
```

---

## Flutter Code Style Rules

1. **No hardcoded strings in UI** — use const where possible
2. **Extract reusable widgets** into `lib/widgets/` (StatCard, PatientListItem, SectionCard, GradientButton, etc.)
3. **Avoid deeply nested widget trees** — break into smaller widgets
4. **Use `const` constructors** wherever possible for performance
5. **Theme-driven styling** — use `Theme.of(context)` for colors/text, not direct hex in every widget
6. **Handle all screen sizes** via `LayoutBuilder` — primary is tablet landscape, fallback is desktop
7. **No backend code** — no http, no supabase, no firebase in this phase
8. **Comment sections** clearly: `// === Section 1: Basic Information ===`

---

## Medical UI Compliance Notes

- Display a disclaimer on the Result screen: *"AI results are screening tools only. Confirmation by a qualified medical professional is required."*
- Confidence scores must be visually prominent (large text)
- Positive TB results should use red/warning color scheme prominently
- All patient data entry fields must be clearly labeled

---

## Build & Run Instructions

```bash
# Test on Windows desktop:
flutter run -d windows

# Check available devices:
flutter devices

# If Windows not available, enable it:
flutter config --enable-windows-desktop
```

---

## Summary Checklist for Trae AI

- [ ] Setup `app_theme.dart` with full ColorScheme and ThemeData
- [ ] Implement `NavRail` widget with 5 items, active/inactive states
- [ ] `ShellRoute` in go_router for screens sharing NavRail
- [ ] Login screen (no nav, gradient bg, white card)
- [ ] Dashboard screen (4 stat cards, recent activity, quick actions)
- [ ] Diagnosis screen (8 form sections + sticky image panel)
- [ ] Camera screen (full screen, overlay guide, capture controls)
- [ ] Result screen (X-ray image, patient summary, AI result card)
- [ ] Patients screen (master-detail, 420px list + detail panel)
- [ ] Dataset screen (data table, search, pagination)
- [ ] Account screen (profile card, form, security, notifications, sign out)
- [ ] Mock data for all screens
- [ ] Windows desktop mouse hover states
- [ ] All touch targets minimum 48px

---

**Version**: 1.0 (Flutter Adaptation)
**Base Guidelines**: TBScreen Design Guidelines v1.0 (April 5, 2026)
**Target Testing**: Windows Desktop (flutter run -d windows)
**Final Target**: Android Tablet Landscape 10–12 inch
