## Implemented Features

### Core Features
- [x] User Authentication
- [x] Functional Supabase Backend
- [x] Video Feed
- [x] Comments
- [x] Likes
- [x] User Profiles
- [x] Followers and Following
- [x] Advanced Search Functionality
- [x] Direct Messaging
- [x] User moderation tools

### Video & Content
- [x] Video tags
- [x] YouTube channel integration
- [x] YouTube video player integration
- [x] Basic recommendation algorithm

### Customization & Themes
- [x] Profile Customisation
- [x] Themes
- [x] Theme generation system
- [x] Community theme marketplace

### Quest System
- [x] Quest screen for connecting categories
- [x] Quest managing system
- [x] Quest version control system
- [x] Dynamic quest colors

### Engagement
- [x] Daily goals

---

## Videos

Users can upload videos to the platform. They can add a title, tags, description, and a thumbnail to their videos.

---

## Video Feed

I've implemented two different video feed and player types: a general video feed and a YouTube video feed.

### General Video Player

The general video player can show every video that has a specified URL that contains the video data. Normally those links end with `.mp4`, `.webm`, or `.ogg`.

### YouTube Video Player

YouTube videos are special. They don't provide direct links to the video data. That's why you need to use an embedded player that shows the video using an IFrame.

These IFrames are a bit more difficult to work with, because the YouTube IFrame API has a lot of rate limits and restrictions.

For example:
- It only allows you to play one video with autoplay at a time
- You have to carefully dispose of the IFrame when switching videos
- You can't preload YouTube videos
- Videos must load when scrolled into view

---

## Comments

The videos can be commented on. You can also like comments and reply to them.

---

## User Profiles

Users have their own profiles where they can see:
- Their videos
- Liked videos
- Followers
- Following users

The profile also shows:
- User bio
- Profile picture
- Total published videos
- Total received likes
- Username and display name

---

## Advanced Search Functionality

Users can search for videos, users, and tags using the search bar.

The search results are calculated using an advanced search algorithm that uses:
- Video title
- Description
- Tags
- Popularity

to determine the relevance of the search results.

---

## Direct Messaging

Users can send direct messages to each other. They can:
- Send text messages
- Share videos

Technically, it also supports group chats, but this is not implemented in the frontend yet.

---

## Profile Customisation

Users can customize their profiles by changing their:
- Profile picture
- Display name
- Username
- Bio

---

## Themes

Users can choose between different themes for the platform. They can import/export their themes as JSON files or share them with the community.

### Theme Generation System

The theme generation system allows users to create their own themes by selecting colors for different elements of the platform. They can then save their themes and share them with the community.

### Community Theme Marketplace

The community theme marketplace allows users to:
- Share their themes
- Browse available themes
- Import themes to their profiles
- Like themes
- Remix themes

Remixing means taking an existing theme, modifying it, and publishing it as a new theme.

---

## Quests

Different topics are represented as "Quests", inspired by similar systems in games.

Quests can:
- Have prerequisites
- Be connected to other quests
- Represent learning dependencies

Example:
"Multiplication" can be a prerequisite for "Division".

Each quest has:
- A color
- A description

Connections may also have level requirements, meaning a quest must be completed multiple times before unlocking the next one.

---

### Quest Managing System

Users can:
- Create quests
- Edit quests
- Delete quests
- Connect quests via prerequisites

---

### Quest Version Control System

After making changes, users can publish them.

Features:
- Every change since the last publish is stored
- Ability to revert to previous versions
- Only changed data is stored
- Individual changes can be removed before publishing
- Changes are merged into a new version

Users can name each change to track what was modified and why.

There is also a feature that suggests names automatically based on the changes (e.g. "Changed color to teal").

---

### Dynamic Quest Colors

Quests can have either static or dynamic colors.

Dynamic colors are calculated based on connected quests.

Example:
- Red + Blue prerequisites → Purple quest

This helps to:
- Visualize relationships between topics
- Create a consistent color scheme
- Generate gradients across the quest map

---

## User Moderation Tools

Users can report other users if they find them inappropriate.

If a user receives too many reports:
- The user is banned

The banned user can Appeal the ban and moderators then review the case and decide whether to lift the ban.

---

## Daily Goals

Every day, users receive a new goal that encourages interaction with the platform.

Examples:
- Watch 30 videos
- Like 5 comments

Additional dynamic homepage cards include:
- Continue Watching
- Recommended for You

---

## Home Page

The home page includes:
- Daily goals
- Discover section (new content)
- Following section (latest content from followed users)

---

## Easter Eggs

I added some Easter Eggs to the platform. Can you find them all?