function [Y, V] = apdcbt(X)
   % Reference : Embedding Binary Image Watermark in DC Components of All
   % Phase Discrete Cosine Biorthogonal Transform
   % Author : Zabir Al Nazi
   % Email : zabiralnazi@codeassign.com
   
   [M, N, z] = size(X);
   if(z ~= 1)
       disp('Implemented for single channel image\n');
   end
   if(M ~= N)
       disp('X should be an N by N matrix\n');
   end
   
   X = double(X);
   Y = zeros(M,N);
   V = zeros(M,N);
   
   for m = 0:M-1
       for n = 0:N-1
           
           if (n == 0 )
               V(m+1,n+1) = (N-m)/(N^2);
           else
               V(m+1,n+1) = ((N-m)*cos((m*n*pi)/N) - ...
                   csc((n*pi)/N)*sin((m*n*pi)/N))/(N^2);
           end
           
       end
   end
   
   Y = V*X*V'; % without optimization
   
  
           
end