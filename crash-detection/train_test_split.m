 
function [TrainX, TrainY, TestX, TestY] = train_test_split()

clear all

close all

load("traindata.mat");

 AllTrainX = train_data_x(1:length(train_data_x), 1);
 ALlTrainY = train_data_y(1:length(train_data_x), 1);
 
 
 length_train = round(length(AllTrainX) - length(AllTrainX)/10);
 length_test = round(length(AllTrainX)/10);
 
 total_length = length(AllTrainX);
 
 s = rng;
 train_radom = randi([1 total_length],1,length_train);
 test_radom = randi([1 total_length],1,length_test);
 
 TrainX = cell(length_train,1);
 TrainY = categorical(length_train,1);
 
 for i=1: length_train
     
     TrainX{i,1} = AllTrainX{train_radom(i),1};
     TrainY(i,1) = ALlTrainY(train_radom(i),1);
     
 end
 
 
 TestX = cell(length_test,1);
 TestY = categorical(length_test,1);
 
  for i=1: length_test
     
     TestX{i,1} = AllTrainX{test_radom(i),1};
     TestY(i,1) = ALlTrainY(test_radom(i),1);
     
  end
 
  