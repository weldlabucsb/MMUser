%Stress Test for pgUpdate command through Muscle Museum
%Assumes that you are working on a test database separate from your main
%one. Already running init

iterations=1000;

usecloseconn=1;

for ii=1:iterations

    obj=BecExp("Test");
    obj.update;
    obj.update;
    
    if usecloseconn
        close(obj.Writer);
    end

    % clear obj;

    pause(0.1);

end