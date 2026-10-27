param([uint32]$TargetPid,[string]$ExpectedExecutable="")
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class AudioDeviceEnumerator {}
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IDeviceEnumerator {
 [PreserveSig] int EnumAudioEndpoints(int flow,uint state,out IntPtr devices);
 [PreserveSig] int GetDefaultAudioEndpoint(int flow,int role,out IAudioDevice device);
}
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IAudioDevice {
 [PreserveSig] int Activate(ref Guid iid,uint context,IntPtr parameters,[MarshalAs(UnmanagedType.IUnknown)] out object instance);
}
[ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionManager {
 [PreserveSig] int GetAudioSessionControl(ref Guid session,uint flags,out IntPtr control);
 [PreserveSig] int GetSimpleAudioVolume(ref Guid session,uint flags,out IntPtr volume);
 [PreserveSig] int GetSessionEnumerator(out ISessionEnumerator sessions);
}
[ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionEnumerator {
 [PreserveSig] int GetCount(out int count);
 [PreserveSig] int GetSession(int index,[MarshalAs(UnmanagedType.IUnknown)] out object control);
}
[ComImport, Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionControl2 {
 [PreserveSig] int GetState(out int state);
 [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
 [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string name,ref Guid context);
 [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string path);
 [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string path,ref Guid context);
 [PreserveSig] int GetGroupingParam(out Guid grouping);
 [PreserveSig] int SetGroupingParam(ref Guid grouping,ref Guid context);
 [PreserveSig] int RegisterAudioSessionNotification(IntPtr callback);
 [PreserveSig] int UnregisterAudioSessionNotification(IntPtr callback);
 [PreserveSig] int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string value);
 [PreserveSig] int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string value);
 [PreserveSig] int GetProcessId(out uint pid);
}
[ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface ISessionVolume {
 [PreserveSig] int SetMasterVolume(float volume,ref Guid context);
 [PreserveSig] int GetMasterVolume(out float volume);
 [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute,ref Guid context);
 [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
}
public static class GameAudioMute {
 public static int Mute(uint target) {
  var enumerator=(IDeviceEnumerator)new AudioDeviceEnumerator(); int matches=0;
  for(int role=0;role<3;role++) {
   IAudioDevice device; Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0,role,out device));
   Guid iid=new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");object managerObject;
   Marshal.ThrowExceptionForHR(device.Activate(ref iid,23,IntPtr.Zero,out managerObject));
   var manager=(ISessionManager)managerObject;ISessionEnumerator sessions;
   Marshal.ThrowExceptionForHR(manager.GetSessionEnumerator(out sessions));int count;
   Marshal.ThrowExceptionForHR(sessions.GetCount(out count));
   for(int i=0;i<count;i++) { object control;Marshal.ThrowExceptionForHR(sessions.GetSession(i,out control));
    uint pid;Marshal.ThrowExceptionForHR(((ISessionControl2)control).GetProcessId(out pid));
    if(pid!=target) continue;
    var volume=(ISessionVolume)control;Guid context=Guid.Empty;bool muted;
    Marshal.ThrowExceptionForHR(volume.SetMute(true,ref context));Marshal.ThrowExceptionForHR(volume.GetMute(out muted));
    if(!muted) throw new Exception("Mute verification failed");matches++;
   }
  }
  if(matches==0) throw new Exception("No audio session for requested game PID");return matches;
 }
}
"@
$taskMuteDeadline=[DateTime]::UtcNow.AddSeconds(15)
while($true) {
    $taskMuteProcess=Get-Process -Id $TargetPid -ErrorAction Stop
    if($ExpectedExecutable -and $taskMuteProcess.Path -ne [IO.Path]::GetFullPath($ExpectedExecutable)){throw 'Audio target identity changed'}
    try { [GameAudioMute]::Mute($TargetPid); break }
    catch { if([DateTime]::UtcNow -ge $taskMuteDeadline){throw}; Start-Sleep -Milliseconds 250 }
}
