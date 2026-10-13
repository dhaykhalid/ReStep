 <p align="center">
  <img src="logo.png" alt="ReStep Logo" width="300">
</p>

## About ReStep

**ReStep** is a graduation project developed by Information Technology students at King Saud University. The project aims to support individuals who experience **Freezing of Gait (FoG)** by providing real-time detection, assistive cueing, and tools for managing FoG-related information.

The system uses wearable **Shimmer3 IMU sensors** to collect movement data and a machine learning model to detect FoG episodes in real time. When an episode is detected, ReStep automatically delivers the user's configured vibration or auditory cue through a connected Wear OS smartwatch to assist them in resuming movement.

A companion **Android mobile application** allows users to manage their information, review FoG episodes, record relevant daily information, and monitor their history and trends.

## Key Features

- **Real-Time FoG Detection** – Monitors movement using Shimmer3 IMU signals and applies a machine learning model to detect FoG episodes as they occur.
- **Configured Cue Delivery** – Automatically delivers the user's configured vibration or auditory cue through the Wear OS smartwatch when FoG is detected.
- **Quick Assistance and Cue Control** – Allows users to manually trigger the configured cue when assistance is needed and stop an active cue.
- **FoG Episode Tracking** – Records detected FoG episodes, including their date, time, and estimated duration.
- **Post-Episode Context Logging** – Allows users to optionally record contextual information associated with FoG episodes.
- **Manual FoG Episode Logging** – Enables users to manually record FoG episodes when needed.
- **FoG History and Statistics** – Provides episode history and summary statistics, including episode frequency and average duration.
- **FoG Report Generation** – Generates structured reports containing episode records and summary information that users may export and share with healthcare professionals.
- **Daily Routine Management** – Allows users to schedule medication times and medical appointments and receive reminders.
- **Emergency Escalation** – Sends an SMS containing the patient's current location, retrieved through Google Location Services, to an emergency contact when predefined escalation conditions are met.
- **Account and Profile Management** – Allows users to manage their account and personal information.

## System Overview

ReStep integrates four main components:

**Shimmer3 IMU Sensors → Android Mobile Application (FoG Detection Model) → Wear OS Smartwatch**

The Shimmer3 IMU sensors capture acceleration and angular velocity data and transmit the collected signals to the Android mobile application using Bluetooth Classic (SPP).

The application processes the sensor data and applies the machine learning model to detect FoG episodes. When FoG is detected, the system triggers the user's configured cue through the Wear OS smartwatch.

The mobile application also manages episode history, daily routine information, and reporting, while backend services support data storage and emergency escalation.

## Technologies Used

| Component | Technology |
|---|---|
| Mobile Application | Flutter / Dart |
| Smartwatch Application | Wear OS |
| Motion Sensing | Shimmer3 IMU |
| Sensor Communication | Bluetooth Classic (SPP) |
| FoG Detection | Machine Learning |
| Database | Firebase |
| Location Services | Google Location Services |
| Emergency Notifications | SMS Gateway API |
| Development Environment | Visual Studio Code |
| Android Development Tools | Android SDK / Android Emulator |
| Project Management | Jira |
| Version Control | Git & GitHub |

## Getting Started

The following instructions explain how to set up and run the ReStep Android application locally.

### Prerequisites

Before running the project, ensure that the following are installed or available:

- Flutter SDK (3.47.7 or compatible)
- Dart SDK (3.13.5 or compatible)
- Visual Studio Code with Flutter and Dart extensions
- Android SDK and Android Emulator, or a physical Android device
- Git
- GitHub Personal Access Token with `read:packages` permission for the Shimmer library

### Launch Instructions

**1. Clone the repository**

```bash
git clone https://github.com/dhaykhalid/ReStep.git
cd ReStep
```

**2. Install Flutter dependencies**

```bash
flutter pub get
```

**3. Configure Shimmer library access**

Create or edit the `gradle.properties` file in the user Gradle directory.

On Windows, the typical location is:

```text
C:\Users\YOUR_NAME\.gradle\gradle.properties
```

Add the following:

```properties
gpr.usr=YOUR_GITHUB_USERNAME
gpr.key=YOUR_GITHUB_TOKEN
```

Replace the placeholders with your GitHub username and personal access token.

Keep your token private and do not commit it to the repository.

**4. Launch an Android device**

Start an Android emulator using Android Studio Device Manager or VS Code, or connect a physical Android device.

**5. Run the application**

Open the project in Visual Studio Code and execute:

```bash
flutter run
```

The ReStep application will build and launch on the connected Android device.

## ReStep Team

Developed by Information Technology students at **King Saud University – College of Computer and Information Sciences**.

### Team Members

- Dhay Alsumayt
- Layan Alfawaz
- Wasan Alamri
- Dalia Alotaibi
- Hessa Alarife

### Supervisor

**Dr. Nora Alhammad**

## Project Status

ReStep is currently under development as part of the **IT 496 Graduation Project** at King Saud University.

The project is being developed incrementally, with ongoing implementation and integration of its mobile application, wearable sensing, FoG detection, smartwatch cueing, and supporting services.

---

<div align="center">

### ReStep
**Step Forward with Confidence**

</div>
