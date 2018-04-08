function y = encoding(img, nType)

% read image and convert to gray scale if necessary
originalImage = imresize(imread('Test_img/cameraman.jpg'),[512 512],'bicubic');
if 1
    %originalImage = rgb2gray(originalImage);
end
originalImage = originalImage(:,:,1);
figure(1), imshow(originalImage), title('Original Image');

% define constants
BITPLANE_NUMBER = 4; %4 % specifies the bitplane number to embedd watermark
ERROR_NUM = 16; %16 % prevents this gray value from being used in embedding
WM_SIZE = 300;
% select the bitplane number and then the corresponding error num from the
% table below
% BITPLANE_NUMBER = [1     2   3   4  5  6  7  8]
% ERROR_NUM       = [128  64  32  16  8  4  2  1]
disp('Encoding...');




% STEP 1: perform necessary preprocessing
%[valCount,X] = imhist(img);

% STEP 2: perfom wavelet decomposition
% Good reconstruction with cdf2.2, haar, sym2
% cdf1.1, cdf3.5
LS = liftwave('cdf4.6','Int2Int');
[CA,CH,CV,CD] = lwt2(double(img),LS);
%[CA,CH,CV,CD] = dwt2(double(img),'haar');
nCA = uint8(255*mat2gray(CA));
nCH = uint8(255*mat2gray(CH));
nCV = uint8(255*mat2gray(CV));
nCD = uint8(255*mat2gray(CD));
figure(13), title('IWT components'),
subplot(2,2,1), imshow(nCA,[]),
subplot(2,2,2), imshow(nCH,[]),
subplot(2,2,3), imshow(nCV,[]),
subplot(2,2,4), imshow(nCD,[]);

% STEP 3: construct binary images from 5th bit of CH, CV and CD
for i=1:size(CH,1)
    for j=1:size(CH,2)
        % for constructing binary image using CH
        binSeq = dec2bin(abs(CH(i,j)),8); % 8 bit binary rep.
        if binSeq(BITPLANE_NUMBER) == '1'
            bICH5(i,j) = 2;
        else
            bICH5(i,j) = 1;
        end
        % for constructing binary image using CV
        binSeq = dec2bin(abs(CV(i,j)),8);
        if binSeq(BITPLANE_NUMBER) == '1'
            bICV5(i,j) = 2;
        else
            bICV5(i,j) = 1;
        end
        % for constructing binary image using CD
        binSeq = dec2bin(abs(CD(i,j)),8);
        if binSeq(BITPLANE_NUMBER) == '1'
            bICD5(i,j) = 2;
        else
            bICD5(i,j) = 1;
        end        
    end
end

% STEP 4a: Compress data in 5th Bit plane of CH
% find how many times 1 occurs in the level 5 binary bICH5 (horizontal)
[xx,yy,val] = find(bICH5 == 1);
totalVals = size(CH,1)*size(CH,2);

% code the sequence using arithmetic coding
count1 = [round((size(xx,1)/totalVals)*100) round(((totalVals - size(xx,1))/totalVals) * 100)];
seq1 = reshape(bICH5,1,size(CH,1)*size(CH,2));
arcCH5 = arithenco(seq1,count1); 
str = sprintf('Original CH Bits Length = %d ------ Compressed CH Bits Length = %d',size(seq1,2),size(arcCH5,2));
disp(str);

% STEP 4b: Compress data in 5th Bit plane of CV
% find how many times 1 occurs in the level 5 binary bICV5 (vertical)
[xx,yy,val] = find(bICV5 == 1);
totalVals = size(CV,1)*size(CV,2);

% code the sequence using arithmetic coding
count2 = [round((size(xx,1)/totalVals)*100) round(((totalVals - size(xx,1))/totalVals) * 100)];
seq2 = reshape(bICV5,1,size(CV,1)*size(CV,2));
arcCV5 = arithenco(seq2,count2); 
str = sprintf('Original CV Bits Length = %d ------ Compressed CV Bits Length = %d',size(seq2,2),size(arcCV5,2));
disp(str);

% STEP 4c: Compress data in 5th Bit plane of CD
% find how many times 1 occurs in the level 5 binary bICD5 (diagonal)
[xx,yy,val] = find(bICD5 == 1);
totalVals = size(CD,1)*size(CD,2);

% code the sequence using arithmetic coding
count3 = [round((size(xx,1)/totalVals)*100) round(((totalVals - size(xx,1))/totalVals) * 100)];
seq3 = reshape(bICD5,1,size(CD,1)*size(CD,2));

arcCD5 = arithenco(seq3,count3); 
str = sprintf('Original CD Bits Length = %d ------ Compressed CD Bits Length = %d',size(seq3,2),size(arcCD5,2));
disp(str);


% STEP 5: read the watermark and reshape it for insertion
watermark = imresize(rgb2gray(imread('code.jpg')),[WM_SIZE WM_SIZE],'bicubic');
%watermark = imresize(DMlcd5,[WM_SIZE WM_SIZE],'bicubic');
watermark = im2bw(watermark);

figure(2), imshow(watermark,[]), title('Code Image');
%figure,imshow(watermark,[]),title('Watermark');
watermark = reshape(watermark,1,WM_SIZE*WM_SIZE);


% STEP 6: Insert the watermark and compressed data into the image
% compute length of data to insert
dataLength = size(watermark,2) + size(arcCH5,2) + size(arcCV5,2) + size(arcCD5,2) + 6*8 + 4*16;%(2*8)*3;
available = size(CH,1)*size(CH,2) + size(CV,1)*size(CV,2) + size(CD,1)*size(CD,2);

if available < dataLength
    disp('Data to Embedd must be less than available limit.');
end

% allocate memory and initialize
embedData = zeros(1,dataLength); 

disp(count1);
disp(count2);
disp(count3);
% insert the header information
str1 = dec2bin(count1(1,1),8); str2 = dec2bin(count1(1,2),8);
header = strcat(str1,str2);
str1 = dec2bin(count2(1,1),8); str2 = dec2bin(count2(1,2),8);
header = strcat(header,str1,str2);
str1 = dec2bin(count3(1,1),8); str2 = dec2bin(count3(1,2),8);
header = strcat(header,str1,str2);
% insert length of each sequence for decoding
str1 = dec2bin(size(arcCH5,2),16); str2 = dec2bin(size(arcCV5,2),16); 
str3 = dec2bin(size(arcCD5,2),16); str4 = dec2bin(size(watermark,2),32);
header = strcat(header,str1,str2,str3,str4);

for i=1:size(header,2)
    if header(1,i) == '1'
        embedData(1,i) = 1;
    else
        embedData(1,i) = 0;        
    end
end
% get the header length
HL = size(header,2);
% concatenate data to get a single compressed data vector
embedData(1,HL+1:HL+size(arcCH5,2)) = arcCH5(1,:);
embedData(1,HL+size(arcCH5,2)+1:(HL+size(arcCH5,2) + size(arcCV5,2))) = arcCV5(1,:);
embedData(1,HL+size(arcCH5,2)+ size(arcCV5,2)+1:(HL + size(arcCH5,2) + size(arcCV5,2) + size(arcCD5,2))) = arcCD5(1,:);
embedData(1,HL+size(arcCH5,2)+ size(arcCV5,2)+size(arcCD5,2)+1:(HL+size(arcCH5,2) + size(arcCV5,2) + size(arcCD5,2)+ size(watermark,2))) = watermark(1,:);
originalBitsLength = HL + size(arcCH5,2)+ size(arcCV5,2)+size(arcCD5,2);

% embedd compressed data, watermark and header information
index = 1; % counter for obtaining 8 bit chunks
brk = 0;
for x=1:size(CH,1)
    for y=1:size(CH,2)
        if CH(x,y) ~= -ERROR_NUM
            neg = 0;
            if CH(x,y) < 0
                neg = 1;
            end
            binSeq = dec2bin(abs(CH(x,y)),8);
            if embedData(1,index) == 1
                binSeq(BITPLANE_NUMBER) = '1';
            else
                binSeq(BITPLANE_NUMBER) = '0';
            end
            num = bin2dec(binSeq);
            if neg == 1
                CH(x,y) = num * -1;
            else
                CH(x,y) = num;
            end

            % break the loop if all watermark bits are embedded
             if index < size(embedData,2)
                index = index + 1;
             else
                 brk = 1; break;
             end
        end
    end
    if brk == 1
        break;
    end
end

if index < size(embedData,2)
    for x=1:size(CV,1)
        for y=1:size(CV,2)
            if CV(x,y) ~= -ERROR_NUM            
                neg = 0;
                if CV(x,y) < 0
                    neg = 1;
                end
                binSeq = dec2bin(abs(CV(x,y)),8);
                if embedData(1,index) == 1
                    binSeq(BITPLANE_NUMBER) = '1';
                else
                    binSeq(BITPLANE_NUMBER) = '0';
                end
                num = bin2dec(binSeq);
                if neg == 1
                    CV(x,y) = num * -1;
                else
                    CV(x,y) = num;
                end

                % break the loop if all watermark bits are embedded
                 if index < size(embedData,2)
                   index = index + 1;
                 else
                     brk = 1; break;
                 end
            end
        end
        if brk == 1
            break;
        end
    end
 end

if index < size(embedData,2)
    for x=1:size(CD,1)
        for y=1:size(CD,2)
            if CD(x,y) ~= -ERROR_NUM                        
                neg = 0;
                if CD(x,y) < 0
                    neg = 1;
                end
                binSeq = dec2bin(abs(CD(x,y)),8);
                if embedData(1,index) == 1
                    binSeq(BITPLANE_NUMBER) = '1';
                else
                    binSeq(BITPLANE_NUMBER) = '0';
                end
                num = bin2dec(binSeq);
                if neg == 1
                    CD(x,y) = num * -1;
                else
                    CD(x,y) = num;
                end

                % break the loop if all watermark bits are embedded
                if index < size(embedData,2)
                    index = index + 1;
                 else
                     brk = 1; break;
                end
            end
        end
        if brk == 1
            break;
        end
    end
 end

% compute inverse integer wavelet transform

watermarkedImage = ilwt2(CA,CH,CV,CD,LS);
nwm = uint8(255*mat2gray(watermarkedImage));
figure(3), imshow(nwm,[]), title('Watermarked Image');

% [tx,ty,tval] = find(watermarkedImage > 256);
% if ~isempty(tx)
%     disp('Watermarked Image values greater than 256');
% end
% [tx,ty,tval] = find(watermarkedImage <= 0);
% if ~isempty(tx)
%     disp('Watermarked Image values less than equal to 0');
% end

imwrite(uint8(watermarkedImage),'Watermarked Image.bmp','bmp');

% str = sprintf('Payload(bpp) = %f -- Embedded Data(Header+Original Bits+Watermark) = %d bits -- Watermark Length = %d bits',(dataLength-originalBitsLength)/(4*(size(CH,1)*size(CH,1))),dataLength+HL,size(watermark,2));
disp(str);

[PSNR_OUT,Z] = psnr(originalImage,watermarkedImage);
squaredErrorImage = (double(originalImage) - double(watermarkedImage)) .^ 2;
% Sum the Squared Image and divide by the number of elements
% to get the Mean Squared Error.  It will be a scalar (a single number).
[rows, columns] = size(originalImage);
mse = sum(sum(squaredErrorImage)) / (rows * columns);

disp('Encoded Image');
str = sprintf('PSNR = %f',PSNR_OUT);

disp(str);

str = sprintf('MSE = %f',mse);

disp(str);

figure(4),
title('Original vs Encoded');
somedata=[PSNR_OUT, mse];
somenames={'PSNR', 'MSE'};
bar(somedata)
set(gca,'xticklabel',somenames)

img = imnoise(img,nType);

figure(5),imshow(img,[]),title('Noise Image');

img = wiener2(img,[5 5]);

figure(6),imshow(img,[]),title('Denoised Image');
%figure,imshow(img,[]),title('Original Image');
%figure,imshow(watermarkedImage,[]),title('Watermarked Image');



save WatermarkInfo watermarkedImage watermark BITPLANE_NUMBER WM_SIZE ERROR_NUM img;
extraction(nType);
% WMI = imread('Watermarked Image.bmp');
% difference = double(watermarkedImage) - double(WMI);
% figure,imshow(difference,[]),title('Difference Image');

