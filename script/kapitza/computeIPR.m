function ipr = computeIPR(adData)
onedData = squeeze(sum(adData,2));
onedData = onedData./repmat(sum(onedData,1), size(onedData,1),1);
size(onedData)
ipr = squeeze(sum(onedData.^2,1));
end