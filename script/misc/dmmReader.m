figure(1)
l = plot(1,1);
render

figure(2)
l2 = loglog(1,1);

watchFolder = "C:\Users\WOODHOUSE\Documents\KickStart\Projects";
watcher = System.IO.FileSystemWatcher(watchFolder);
watcher.Filter = "*.csv";
watcher.EnableRaisingEvents = true;
listener = addlistener(watcher,'Created', @(src,event) onChanged(src,event,l,l2));
listener.Enabled = true;

function onChanged(~,evt,l,l2)
% obj.TempDataPath = [obj.TempDataPath string(evt.FullPath.ToString())];
% if numel(obj.TempDataPath) == obj.DataGroupSize
%     notify(obj,'NewRunFinished');
%     obj.TempDataPath = [];
% end
% disp("yes")
pause(2)
delay = 0.2;
% duration = 1;
dataPath = string(evt.FullPath.ToString());
data = readtable(dataPath);
t = data.DMM_1Time_s_(1:end-10);
V = data.DMM_1MX_b_X_(1:end-10);
idx = find(t>delay);
if mod(numel(idx),2)~=0
    idx = [idx(1)-1,idx];
end
L = numel(idx);
T = t(2) - t(1);
t = (0:L-1)*T;
V = V(idx);
Y = fft(V);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = (1/T)*(0:(L/2))/L;

l.XData = t;
l.YData = V;
l2.XData = f;
l2.YData = abs(P1).^2;

disp(std(V))
end