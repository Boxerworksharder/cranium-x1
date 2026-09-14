class AppConstants {
  static const String defaultEspIp = '192.168.0.210';
  static const String prefDeviceHost = 'pref_device_host';
  static const String prefAutoPoll = 'pref_auto_poll';

  // API Endpoints
  static const String epStatus = '/api/status';
  static const String epTasks = '/api/tasks';
  static const String epTaskAdd = '/api/tasks/add';
  static const String epTaskToggle = '/api/tasks/toggle';
  static const String epTaskDelete = '/api/tasks/delete';
  static const String epTaskUpdate = '/api/tasks/update';

  static const String epReminders = '/api/reminders';
  static const String epReminderAdd = '/api/reminders/add';
  static const String epReminderDelete = '/api/reminders/delete';
  static const String epReminderUpdate = '/api/reminders/update';

  static const String epAction = '/api/action';
  static const String epBrightness = '/api/brightness';
  static const String epGoal = '/api/goal';
  static const String epClientAdd = '/api/sections/add';
  static const String epClientDelete = '/api/sections/delete';
  static const String epClientUpdate = '/api/sections/update';

  static const String epSessionStart = '/api/session/start';
  static const String epSessionPause = '/api/session/pause';
  static const String epSessionResume = '/api/session/resume';
  static const String epSessionStop = '/api/session/stop';
  static const String epTally = '/api/tally';
  static const String epWellness = '/api/wellness';
  static const String epWellnessTest = '/api/wellness/test';
}
