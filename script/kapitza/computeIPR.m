function ipr = computeIPR(adData)
onedData = squeeze(sum(adData,2));
onedData = onedData./sum(onedData,1);
ipr = squeeze(sum(onedData.^2,1));
end