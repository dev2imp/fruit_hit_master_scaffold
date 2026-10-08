# Keep WorkManager internal components from being stripped or renamed by R8
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.background.systemjob.SystemJobService { *; }
-dontwarn androidx.work.impl.**
