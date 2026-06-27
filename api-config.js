* {
  box-sizing: border-box;
}

:root {
  color-scheme: light;
  --bg: #f2f2f7;
  --panel: #ffffff;
  --text: #1c1c1e;
  --muted: #8e8e93;
  --line: #e5e5ea;
  --blue: #007aff;
  --green: #34c759;
  --orange: #ff9500;
  --red: #ff3b30;
  --purple: #af52de;
  --radius: 16px;
}

body {
  margin: 0;
  min-height: 100vh;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
  letter-spacing: 0;
}

button,
input,
textarea,
select {
  font: inherit;
}

button {
  cursor: pointer;
}

.app-shell {
  min-height: 100vh;
  max-width: 760px;
  margin: 0 auto;
  padding: env(safe-area-inset-top) 14px calc(88px + env(safe-area-inset-bottom));
}

.topbar {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
  padding: 18px 4px 14px;
}

.large-title {
  margin: 0;
  font-size: 34px;
  line-height: 1.1;
  font-weight: 780;
}

.caption {
  margin: 5px 0 0;
  color: var(--muted);
  font-size: 14px;
}

.pill {
  display: inline-flex;
  align-items: center;
  min-height: 32px;
  padding: 0 12px;
  border-radius: 999px;
  background: rgba(0, 122, 255, 0.12);
  color: var(--blue);
  font-size: 13px;
  font-weight: 700;
  white-space: nowrap;
}

.progress-card,
.group,
.question-card,
.upload-card,
.panel {
  background: var(--panel);
  border-radius: var(--radius);
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.04);
}

.progress-card {
  padding: 16px;
  margin-bottom: 14px;
}

.progress-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.big-number {
  font-size: 34px;
  font-weight: 800;
}

.progress-bar {
  height: 8px;
  margin-top: 12px;
  overflow: hidden;
  border-radius: 999px;
  background: #d7e8ff;
}

.progress-fill {
  width: var(--progress, 0%);
  height: 100%;
  border-radius: inherit;
  background: var(--blue);
}

.primary,
.secondary,
.danger {
  width: 100%;
  min-height: 50px;
  border: 0;
  border-radius: 14px;
  font-weight: 730;
  font-size: 16px;
}

.primary {
  background: var(--blue);
  color: #fff;
}

.secondary {
  background: #e5e5ea;
  color: var(--text);
}

.danger {
  background: rgba(255, 59, 48, 0.12);
  color: var(--red);
}

.button-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin: 12px 0;
}

.section-label {
  padding: 14px 4px 8px;
  color: var(--muted);
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
}

.group {
  overflow: hidden;
  margin-bottom: 14px;
}

.cell {
  min-height: 58px;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-bottom: 1px solid var(--line);
}

.cell:last-child {
  border-bottom: 0;
}

.tile-icon {
  width: 38px;
  height: 38px;
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  border-radius: 10px;
  color: #fff;
  font-weight: 800;
}

.blue { background: var(--blue); }
.green { background: var(--green); }
.orange { background: var(--orange); }
.red { background: var(--red); }
.purple { background: var(--purple); }
.gray { background: var(--muted); }

.cell-main {
  flex: 1;
  min-width: 0;
}

.cell-title {
  font-size: 16px;
  font-weight: 680;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.cell-sub {
  margin-top: 3px;
  color: var(--muted);
  font-size: 13px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.chev {
  color: #c7c7cc;
  font-size: 24px;
}

.paper-cell {
  align-items: flex-start;
}

.mini-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-top: 10px;
}

.mini-btn {
  min-height: 34px;
  border: 0;
  border-radius: 999px;
  background: rgba(0, 122, 255, 0.12);
  color: var(--blue);
  font-size: 13px;
  font-weight: 720;
}

.bottom-tabs {
  position: fixed;
  left: 50%;
  bottom: 0;
  z-index: 20;
  width: min(760px, 100%);
  transform: translateX(-50%);
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  height: calc(74px + env(safe-area-inset-bottom));
  padding: 8px 0 env(safe-area-inset-bottom);
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  background: rgba(248, 248, 248, 0.88);
  backdrop-filter: blur(16px);
}

.tab {
  border: 0;
  background: transparent;
  color: var(--muted);
  font-size: 11px;
  font-weight: 650;
}

.tab span {
  display: block;
  margin-bottom: 2px;
  font-size: 22px;
  line-height: 1.1;
}

.tab.active {
  color: var(--blue);
}

.upload-card {
  padding: 16px;
  margin-bottom: 14px;
}

.textarea,
.input,
.select {
  width: 100%;
  border: 1px solid var(--line);
  border-radius: 12px;
  background: #fff;
  color: var(--text);
  outline: 0;
}

.textarea {
  min-height: 170px;
  resize: vertical;
  padding: 12px;
  line-height: 1.45;
}

.input,
.select {
  min-height: 44px;
  padding: 0 12px;
}

.field {
  margin-bottom: 12px;
}

.field label {
  display: block;
  margin-bottom: 6px;
  color: var(--muted);
  font-size: 13px;
  font-weight: 650;
}

.warning-list {
  margin: 10px 0 0;
  padding-left: 18px;
  color: var(--orange);
  font-size: 13px;
  line-height: 1.45;
}

.editor-card,
.question-card,
.panel {
  padding: 16px;
  margin-bottom: 14px;
}

.option-grid {
  display: grid;
  gap: 10px;
}

.option-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  min-height: 52px;
  padding: 10px 12px;
  border: 1px solid transparent;
  border-radius: 14px;
  background: #fff;
  color: var(--text);
  text-align: left;
}

.option-row.selected {
  border-color: var(--blue);
  background: #eef6ff;
}

.choice-dot {
  width: 28px;
  height: 28px;
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #e5e5ea;
  color: #3a3a3c;
  font-weight: 750;
}

.selected .choice-dot {
  background: var(--blue);
  color: #fff;
}

.question-meta {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  color: var(--muted);
  font-size: 13px;
  margin-bottom: 12px;
}

.question-text {
  font-size: 20px;
  line-height: 1.4;
  font-weight: 720;
}

.result-box {
  margin-top: 12px;
  padding: 12px;
  border-radius: 14px;
  background: #fff;
  border: 1px solid var(--line);
  line-height: 1.5;
}

.result-box.correct {
  border-color: rgba(52, 199, 89, 0.45);
  background: rgba(52, 199, 89, 0.08);
}

.result-box.wrong {
  border-color: rgba(255, 59, 48, 0.45);
  background: rgba(255, 59, 48, 0.08);
}

.empty {
  padding: 24px 16px;
  text-align: center;
  color: var(--muted);
}

.small {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
}

@media (min-width: 760px) {
  .app-shell {
    padding-left: 22px;
    padding-right: 22px;
  }
}
