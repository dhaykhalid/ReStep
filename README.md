
##  About ReStep

**ReStep** is a graduation project developed to support individuals who experience **Freezing of Gait (FoG)**.

The system uses wearable **Shimmer3 IMU sensors** to collect movement data and a machine learning model to detect FoG episodes in real time. When an episode is detected, ReStep automatically delivers the user's configured cue through a connected Wear OS smartwatch to assist them in resuming movement.

A companion **Android mobile application** allows users to manage their information, review FoG episodes, record relevant daily information, and view their history and trends.

---
## Key Features

- **Real-Time FoG Detection** – Continuously monitors movement using Shimmer3 IMU signals and applies a machine learning model to detect Freezing of Gait episodes as they occur.

- **Configured Cue Delivery** – Automatically delivers the user's configured vibration or auditory cue through the Wear OS smartwatch when FoG is detected.

- **Quick Assistance and Cue Control** – Allows the user to manually trigger the configured cue when assistance is needed and stop an active cue.

- **FoG Episode Tracking** – Records detected FoG episodes, including information such as date and time, estimated duration.

- **Post-Episode Context Logging** – Allows the user to optionally record contextual information about what they were doing or what was happening when a FoG episode occurred.

- **Manual FoG Episode Logging** – Allows the user to manually record a FoG episode when needed.

- **FoG History and Statistics** – Allows users to review previous episodes and summary statistics such as episode frequency and average duration.

- **FoG Report Generation** – Generates structured FoG reports containing summary information and episode records that users may choose to export and share with healthcare professionals.

- **Daily Routine Management** – Allows users to schedule medication times and medical appointments and receive reminders at specified times.

- **Emergency Escalation** – Sends an emergency message to an emergency contact when predefined escalation conditions are met.

- **Account and Profile Management** – Allows users to manage their account and profile information.
---
##  System Overview

ReStep consists of four main components:

**Shimmer3 IMU Sensors → FoG Detection Model → Wear OS Smartwatch → Android Mobile Application**

The wearable sensors continuously capture acceleration and angular velocity data. The collected signals are processed and analyzed by the FoG detection model. When FoG is detected, the system triggers the user's configured cue through the smartwatch while episode information is managed through the mobile application.

---

##  Technologies

| Component | Technology |
|---|---|
| Mobile Application | Flutter / Dart |
| Smartwatch | Wear OS |
| Motion Sensing | Shimmer3 IMU |
| FoG Detection | Machine Learning |
| Database | Firebase |
| Development Environment | Visual Studio Code |
| Project Management | Jira |
| Version Control | Git & GitHub |

---

##  ReStep Team

Developed by Information Technology students at  
**King Saud University – College of Computer and Information Sciences**

**Team Members**

- Dhay Alsumayt
- Layan Alfawaz
- Wasan Alamri
- Dalia Alotaibi
- Hessa Alarife

### Supervisors
 
**Dr. Nora Alhammad**

---

##  Project Status

ReStep is currently under development as part of the **IT 496 Graduation Project**.

---

<div align="center">

### ReStep
**Step Forward with Confidence**

</div>
