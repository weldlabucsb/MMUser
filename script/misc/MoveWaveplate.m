function wfl = MoveWaveplate(targetAngle)

% % Clear environment
% clear; clc;

% Add Kinesis .NET assemblies (update path if needed)
NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.DeviceManagerCLI.dll');
NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.GenericMotorCLI.dll');
NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.DCServoCLI.dll');

% Import namespaces
import Thorlabs.MotionControl.DeviceManagerCLI.*;
import Thorlabs.MotionControl.GenericMotorCLI.*;
import Thorlabs.MotionControl.KCube.DCServoCLI.*;

% Replace with your device serial number
serialNumber = '27250208';

% Build device list
DeviceManagerCLI.BuildDeviceList();
DeviceManagerCLI.GetDeviceListSize();

% Create device object
device = KCubeDCServo.CreateKCubeDCServo(serialNumber);
pause(0.5);
% Connect to device
device.Connect(serialNumber);

% Wait for settings to initialize
pause(2);

% Ensure device is initialized
device.StartPolling(250);  % ms polling rate
pause(0.5);

device.EnableDevice();
pause(0.5);

% Load motor configuration
motorconfiguration=device.LoadMotorConfiguration(serialNumber);


% ---- HOME (IMPORTANT if not already homed) ----
% fprintf('Homing device...\n');
% device.Home(60000); % timeout in ms
% fprintf('Homing complete.\n');

% ---- MOVE TO ANGLE ----
% Target angle in degrees
% targetAngle = 45.0;

% Convert to .NET Decimal type
target = System.Decimal(targetAngle);

fprintf('Moving to %.2f degrees...\n', targetAngle);

% Move with timeout (ms)
device.MoveTo(target, 60000);

fprintf('Move complete.\n');

% Optional: read position
% currentPos = device.Position;
% fprintf('Current position: %.4f degrees\n', double(currentPos));

% Stop polling and disconnect
device.StopPolling();
device.Disconnect();

disp('Done.');
wfl = WaveformList("1",waveformOrigin={ConstantWave(duration = 0.001,offset = 0)});

end