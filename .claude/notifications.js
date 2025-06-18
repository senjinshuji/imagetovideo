const { exec } = require('child_process');

class NotificationManager {
  constructor() {
    this.enabled = true;
  }

  showNotification(title, message) {
    if (!this.enabled) return;

    // macOS通知を表示
    const script = `osascript -e 'display notification "${message}" with title "${title}" sound name "Glass"'`;
    
    exec(script, (error, stdout, stderr) => {
      if (error) {
        console.log('通知の表示に失敗しました:', error.message);
      }
    });
  }

  onTaskComplete(taskName = 'タスク') {
    this.showNotification('Claude Code', `${taskName}が完了しました`);
  }

  onError(errorMessage) {
    this.showNotification('Claude Code - エラー', errorMessage);
  }
}

module.exports = NotificationManager;