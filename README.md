# 🚗 DriveCare+ (BIT34103 – Mobile Application Development)

Welcome to the **DriveCare+** repository! This project is set up with a secure **Firebase Auth & Cloud Firestore** backend, interactive calculators, a driving simulator, and standard styling. 

---

## 👥 Git & GitHub Collaboration Guide
If you are new to Git and GitHub, **don't panic!** This guide contains everything you need to know to collaborate smoothly on our project without breaking each other's code.

---

### 🌿 Why We Use "Branches"
Think of our project as a **shared folder**. If both of us edit the exact same file at the exact same second, our edits will overwrite each other. 
To prevent this, we use **Branches**:
* **`main` Branch**: This is the stable, fully working version of our app. **Never edit files directly on `main`!**
* **Feature Branches**: Before you start writing any code, you will create a personal branch (like a private photocopy of the code). You do all your work there. Once it's finished and tested, we merge it back into `main` together.

---

### 🔄 The Daily 3-Step "Golden Loop"

Follow this workflow every time you work on the app to avoid errors and merge conflicts.

#### ☀️ Step 1: Start of Day (Get the Latest Code)
Before you write any code, make sure you have the newest changes your teammates pushed.

1. Open your terminal in VS Code and switch to `main`:
   ```powershell
   git checkout main
   ```
2. Pull the newest changes from GitHub to your computer:
   ```powershell
   git pull origin main
   ```
3. Create your own branch for your task (Use a descriptive name like `feature/yourname-screenname`):
   ```powershell
   git checkout -b feature/aizat-refuel-calculator
   ```

Now you are in your safe sandbox! You can run the app and edit files freely.

---

#### 💻 Step 2: Coding & Testing
* Work on your specific files (e.g., adding a button, designing a page, or linking a database).
* Run `flutter run` frequently to make sure your changes are working.
* **Tip**: Tell your teammates what files you are editing so they don't work on the same file at the same time!

---

#### 🌙 Step 3: End of Day (Save & Push Your Work)
When your feature is working and ready to share, save it to GitHub.

1. Stage your changes:
   ```powershell
   git add .
   ```
2. Commit (save) your changes with a clear description:
   ```powershell
   git commit -m "Added a dynamic list to show past refuel logs"
   ```
3. Push your branch to GitHub for your teammate to see:
   ```powershell
   git push origin feature/yourname-screenname
   ```

---

### 🤝 How to Merge Your Work (Pull Requests)

Once you push your branch, do **not** merge it on your computer. Merge it on the GitHub website:

1. Go to our repository page on [GitHub](https://github.com/).
2. You will see a yellow banner saying: **"Compare & pull request"**. Click on it!
3. Add a short description of what you completed, then click **Create pull request**.
4. Send the link to your teammate to review!
5. If there are no conflicts, click the green **"Merge pull request"** button to combine your code into the `main` branch. 

---

### ⚠️ What is a "Merge Conflict" and How to Fix It?
A merge conflict happens when you and a teammate edit the **same line of the same file** on different branches, and Git doesn't know which one to keep.

If you see a merge conflict warning in VS Code, **stay calm!** It is easy to fix:
1. VS Code will highlight the conflicting lines in **Red** and **Green**.
2. You will see three options above the conflict:
   * **Accept Current Change**: Keeps your version.
   * **Accept Incoming Change**: Keeps your teammate's version.
   * **Accept Both Changes**: Keeps both of them.
3. Simply click the option that makes sense, save the file, commit, and push!

---

## 🛠️ Flutter Development Tips
* To get all packages when you first download the repository, run:
  ```powershell
  flutter pub get
  ```
* Before pushing your branch, run the static analyzer to make sure there are no errors in your code:
  ```powershell
  flutter analyze
  ```
* If you experience compilation locks or build errors locally, stop gradle daemons and try running:
  ```powershell
  flutter clean
  flutter run
  ```

Let's work together to make **DriveCare+** an amazing application! 🚀
