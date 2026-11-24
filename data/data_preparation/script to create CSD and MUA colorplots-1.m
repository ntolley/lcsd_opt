clear all;
load('D:\1-wi054055014@op')

newadrate =1000;
timeframe_baseline   = [-1000 1000];
epoch_tframe            = [-1000 1000];  
time = epoch_tframe(1):1000/newadrate:epoch_tframe(2);
trig01=anatrig{1};


XX=find(triglength{1,1}==4); %these are the Standrads
XXX=trig01(1,XX);%times of the standrads
x1 = round(epoch_tframe(1)*(newadrate/1000));
x2 = round(epoch_tframe(2)*(newadrate/1000));

%60Hz filter
d1 = designfilt('bandstopiir','FilterOrder',2, ...
    'HalfPowerFrequency1',59,'HalfPowerFrequency2',61, ...
    'DesignMethod','butter','SampleRate',newadrate);
d2 = designfilt('bandstopiir','FilterOrder',2, ...
    'HalfPowerFrequency1',119,'HalfPowerFrequency2',121, ...
    'DesignMethod','butter','SampleRate',newadrate);
%         d3 = designfilt('bandstopiir','FilterOrder',2, ...
%             'HalfPowerFrequency1',179,'HalfPowerFrequency2',181, ...
%             'DesignMethod','butter','SampleRate',eraw.adrate);
%         d4 = designfilt('bandstopiir','FilterOrder',2, ...
%             'HalfPowerFrequency1',239,'HalfPowerFrequency2',241, ...
%             'DesignMethod','butter','SampleRate',eraw.adrate);

for i=1:size(cntm,1)
    cntm(i,:)=filtfilt(d1,cntm(i,:));
    cntm(i,:)=filtfilt(d2,cntm(i,:));
    %                 cntm(i,:)=filtfilt(d3,cntm(i,:));
    %                 cntm(i,:)=filtfilt(d4,cntm(i,:));
    cntc(i,:)=filtfilt(d1,cntc(i,:));
    cntc(i,:)=filtfilt(d2,cntc(i,:));
    %                 cntc(i,:)=filtfilt(d3,cntc(i,:));
    %                 cntc(i,:)=filtfilt(d4,cntc(i,:));
end


%%%% %epoch around standrds only
for i=1:length(XXX)
    eegm(:,i,:)=cntm(:,XXX(i)+x1:XXX(i)+x2);%epoching the mua
    eegc(:,i,:)=cntc(:,XXX(i)+x1:XXX(i)+x2);%epoching the csd
end
  % baseline correct using the entire epoch 
                     for i1=1:size(eegm,1)
                         for iii=1:size(eegm,2)
                             eegmb(i1,iii,:)   = squeeze(eegm(i1,iii,:))-squeeze(mean(eegm(i1,iii,max(find(time<=timeframe_baseline(1))):max(find(time<=timeframe_baseline(2)))),3));
                             eegcb(i1,iii,:)   = squeeze(eegc(i1,iii,:))-squeeze(mean(eegc(i1,iii,max(find(time<=timeframe_baseline(1))):max(find(time<=timeframe_baseline(2)))),3));
                         end
                     end

                     %make CSD figure
                     curfig = figure;
                     set(curfig,'position',[100   50  800   800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto')
                     axpos=[0.1 0.1 0.8 0.8];
                     figureax1a=axes('Position',axpos);
                     [cax2] = csd_maker_no_subplot07(squeeze(mean(eegcb(:,:,:),2)),time,1,[-300 700],[0 0],[-1.5 1.5],axpos,figureax1a);% can change [-1.5 1.5] to change the scale of the CSD
                     colormap(figureax1a,flipud(jet))
                     title([ ' CSD to BF,caxis ' num2str(cax2)  ',N=' num2str(length(XXX)) ],'FontSize',9)
                      print('-djpeg','-r300',[dir1   ',CSD to BF'  '.jpg']) %save to the directory (dir1)

                     %make MUA figure
                      curfig = figure;
                     set(curfig,'position',[100   50  800   800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto')

                     axpos=[0.1 0.1 0.8 0.8];
                     %                     axpos=[0.1 0.4 0.5 0.5];
                     figureax1a=axes('Position',axpos);
                     [cax2] = csd_maker_no_subplot07(squeeze(mean(eegmb(:,:,:),2)),time,0,[-300 700],[0 0],[],axpos,figureax1a); %same function as to make CSD but change a variable from 1 to 0 for MUA
                     colormap(figureax1a,hot)
                     title([ ' MUAepoch to BF,caxis ' num2str(cax2)  ',N=' num2str(length(XXX)) ],'FontSize',9)
                     print('-djpeg','-r300',[dir1 ' ,MUAepoch to BF'  '.jpg'])



  %%% %epoch around Devs only
  XXd=find(triglength{1,1}==8); %these are the Devs
  XXXd=trig01(1,XXd);%times of the Devs

%%%% %epoch around Devs only
 for i=1:length(XXXd)
     eegmd(:,i,:)=cntm(:,XXXd(i)+x1:XXXd(i)+x2);%epoching the mua
     eegcd(:,i,:)=cntc(:,XXXd(i)+x1:XXXd(i)+x2);%epoching the csd
 end
  % baseline correct using the entire epoch 
 for i1=1:size(eegmd,1)
     for iii=1:size(eegmd,2)
         eegmbd(i1,iii,:)   = squeeze(eegmd(i1,iii,:))-squeeze(mean(eegmd(i1,iii,max(find(time<=timeframe_baseline(1))):max(find(time<=timeframe_baseline(2)))),3));
         eegcbd(i1,iii,:)   = squeeze(eegcd(i1,iii,:))-squeeze(mean(eegcd(i1,iii,max(find(time<=timeframe_baseline(1))):max(find(time<=timeframe_baseline(2)))),3));
     end
 end

 %%CSD to Dev
 curfig = figure;
 set(curfig,'position',[100   50  800   800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto')
 axpos=[0.1 0.1 0.8 0.8];
 figureax1a=axes('Position',axpos);
 [cax2] = csd_maker_no_subplot07(squeeze(mean(eegcbd(:,:,:),2)),time,1,[-300 700],[0 0],[],axpos,figureax1a);
 colormap(figureax1a,flipud(jet))
 title([ ' CSD to Dev,caxis ' num2str(cax2)  ',N=' num2str(length(XXXd)) ],'FontSize',9)
  print('-djpeg','-r300',[dir1   ',CSD to Dev'  '.jpg']) %save to the directory (dir1)

    %make MUA figure
                      curfig = figure;
                     set(curfig,'position',[100   50  800   800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto')

                     axpos=[0.1 0.1 0.8 0.8];
                     %                     axpos=[0.1 0.4 0.5 0.5];
                     figureax1a=axes('Position',axpos);
                     [cax2] = csd_maker_no_subplot07(squeeze(mean(eegmbd(:,:,:),2)),time,0,[-300 700],[0 0],[-0.24 0.979],axpos,figureax1a); %set the MUA scaleto that of the standrad
                     colormap(figureax1a,hot)
                     title([ ' MUAepoch to DEV,caxis ' num2str(cax2)  ',N=' num2str(length(XXXd)) ],'FontSize',9)
                     print('-djpeg','-r300',[dir1 ' ,MUAepoch to Dev'  '.jpg'])


   