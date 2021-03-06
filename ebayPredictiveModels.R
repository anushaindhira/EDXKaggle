# KAGGLE COMPETITION (EDX): Predict whether an iPad is going to sell on ebay

'This file contains predictive models and experimentation while I was building the models during the competition'

rm(list= ls())
ebaytrain = read.csv('./EDXKaggle/ebayiPadTrain.csv', stringsAsFactors = FALSE) # training set provided in Kaggle

ebaytrain$TotalWords = nchar(ebaytrain$description) # To evaluate whether the extent of the description is a predictor
ebaytrain$lowstartprice = ifelse(ebaytrain$startprice <= 242, 1, 0) # To evaluate whether low price is a good predictor
ebaytrain$nodescription = ifelse(nchar(ebaytrain$description)==0,1,0) # To evaluate whether not having a description is a good predictor
ebaytrain$goodcon = ifelse(grepl("good condition",ebaytrain$description,fixed=TRUE), 1, 0) # To evaluate whether descriptions including "good condition" are good predictors

for (i in 4:9) { ebaytrain[,i] = as.factor(ebaytrain[,i]) }

ebaytrain = subset(ebaytrain, productline !='iPad 5' & productline !='iPad mini Retina') # the products iPad mini and iPad 5 are not present in test set
ebaytrain$productline = factor(ebaytrain$productline) # to remove the extra factor names

proportions = list(Bid = table(ebaytrain$biddable, ebaytrain$sold), LowStartPrice = table(ebaytrain$lowstartprice, ebaytrain$sold), NoDescription = table(ebaytrain$nodescription, ebaytrain$sold), GoodCondition = table(ebaytrain$goodcon, ebaytrain$sold), Carrier = table(ebaytrain$carrier, ebaytrain$sold), Product = table(ebaytrain$productline, ebaytrain$sold))

library(tm)
library(SnowballC)
# analyse text in the description variable
CorpusDescription = Corpus(VectorSource(ebaytrain$description))
CorpusDescription = tm_map(CorpusDescription, content_transformer(tolower), lazy=TRUE)
CorpusDescription = tm_map(CorpusDescription, PlainTextDocument, lazy=TRUE)
CorpusDescription = tm_map(CorpusDescription, removePunctuation, lazy=TRUE)
CorpusDescription = tm_map(CorpusDescription, removeWords, stopwords("english"), lazy=TRUE)
CorpusDescription = tm_map(CorpusDescription, stemDocument, lazy=TRUE)

dtm = DocumentTermMatrix(CorpusDescription)
sparse = removeSparseTerms(dtm, 0.99) # I played a lot with this number and it did not really affect the predictions
DescriptionWords = as.data.frame(as.matrix(sparse))
colnames(DescriptionWords) = make.names(colnames(DescriptionWords))

ebaytrain$WordCount = rowSums(DescriptionWords) # to determine whether the number of stemed words are a good predictor 
newtrain = cbind(ebaytrain, DescriptionWords)

library(caTools)
set.seed(144)
spl = sample.split(ebaytrain$sold, SplitRatio = 0.7)

######################################################################
# First models : Using non-text variables + TotalWord count
#I separate my training set in training and testing to verify the accuracy of my models
# Models are evaluated by the auc ('Area under the curve')

train = subset(ebaytrain, spl == T)
test = subset(ebaytrain, spl == F)
train$description = NULL # remove description column
test$description = NULL
train$UniqueID = NULL # remove ID column
test$UniqueID = NULL

modelsFit = NULL
#First model: logistic regression using all the variables
logReg = glm(sold ~., data = train, family = binomial)
testPred = predict(logReg, newdata = test, type = 'response')
library(ROCR)
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values)  #0.860241 & AIC: 1236.6
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = c('logReg1', round(accuracy, 4), round(auc, 4))
names(modelsFit) = c('Model #', 'Accuracy', 'auc')

#removing some non-significant variables
logReg = glm(sold ~. -color-carrier-TotalWords, data = train, family = binomial)
testPred = predict(logReg, newdata = test, type = 'response')
library(ROCR)
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values)   #0.8604362
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('logReg2', round(accuracy, 4), round(auc, 4)))
rownames(modelsFit) = NULL

logReg = glm(sold ~. -color-carrier-TotalWords-goodcon-nodescription-lowstartprice, data = train, family = binomial)
testPred = predict(logReg, newdata = test, type = 'response')
library(ROCR)
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values)   #0.8644184 & AIC: 1220.5: THIS LOOKS LIKE THE BEST, best auc and smallest AIC
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('logReg3', round(accuracy, 4), round(auc, 4)))

logReg = glm(sold ~. -color-carrier-goodcon-nodescription-lowstartprice-WordCount, data = train, family = binomial)
testPred = predict(logReg, newdata = test, type = 'response')
library(ROCR)
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) #0.8629088 & AIC: 1222.2
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('logReg4', round(accuracy, 4), round(auc, 4)))
#All Logistic regression models show  roughly the same auc

######################################################################
# Second models: random forest using non-text variables + TotalWord count
library(randomForest)
train$sold = as.factor(train$sold)
test$sold = as.factor(test$sold)
set.seed(144)
ebayRF =  randomForest(sold ~., data = train)
testPred = predict(ebayRF, newdata = test, type = 'prob')[,2]
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) #0.8725974
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable)
modelsFit = rbind(modelsFit, c('RandomForest1', round(accuracy, 4), round(auc, 4)))

ebayRF$importance # we see that goodcon and nodescription do not contribute much to decrease the impurity

train$goodcon = NULL
train$nodescription = NULL
test = test
test$goodcon = NULL
test$nodescription = NULL
set.seed(144)
ebayRF =  randomForest(sold ~., data = train)
testPred = predict(ebayRF, newdata = test, type = 'prob')[,2]
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) #0.8763908 
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('RandomForest2', round(accuracy, 4), round(auc, 4)))

train$lowstartprice = NULL
train$carrier = NULL
train$color = NULL
test$lowstartprice = NULL
test$carrier = NULL
test$color = NULL
set.seed(2000)
ebayRF =  randomForest(sold ~., data = train)
testPred = predict(ebayRF, newdata = test, type = 'prob')[,2]
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) #0.8685306
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('RandomForest3', round(accuracy, 4), round(auc, 4)))

train$WordCount = NULL
test$WordCount = NULL
set.seed(2000)
ebayRF =  randomForest(sold ~., data = train)
testPred = predict(ebayRF, newdata = test, type = 'prob')[,2]
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.8760395
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('RandomForest4', round(accuracy, 4), round(auc, 4)))

png(filename = "./EDXKaggle/aucCurveRF4.png", width = 480, height = 480, units = "px")
ROCRperf = performance(ROCRpred, "tpr", "fpr")
plot(ROCRperf, colorize=TRUE, print.cutoffs.at=seq(0,1,by=0.1), text.adj=c(-0.2,1.7))
dev.off()

# All the random forest trees have aproximately the same auc.
# From the random forest and logistic regressions it seems that the variables I chose to evaluate (lowprice, 
# good condition, lowstartprice, and nodescription) are not really contributing as predictors of sale.

################################################################
# MODELS CONSIDERING TEXT VARIABLE 'DESCRIPTION'

train = subset(newtrain, spl == T)
test = subset(newtrain, spl == F)
train$UniqueID = NULL
test$UniqueID = NULL
train$description = NULL
test$description = NULL

#RF
train$sold = as.factor(train$sold)
test$sold = as.factor(test$sold)

set.seed(2000)
ebayRF = randomForest(sold ~., data = train)
testPred = predict(ebayRF, newdata = test, type = 'prob')[,2]
ROCRpred = prediction(testPred, test$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) #0.8606574
predictionsTable = table(test$sold, testPred > 0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('RF including Text', round(accuracy, 4), round(auc, 4)))

ebayRF$importance # we see that the different words contribute very little to decreasing the impurity
# therefore, the bag of words does not improve the accuracy of our model over the ones evaluated above

######################################################################################
# Fourth model; different models for 'auction' and 'buy it now'

ebaytrainbid = subset(ebaytrain, biddable == 1)
ebaytrainbuyitnow = subset(ebaytrain, biddable == 0)

ebaytrainbid = ebaytrainbid[,-c(1,2,11)] 
ebaytrainbuyitnow = ebaytrainbuyitnow[,-c(1,2,11)]

set.seed(200)
spl2 = sample.split(ebaytrainbid$sold, SplitRatio = 0.7)
trainbid = subset(ebaytrainbid, spl2 == TRUE)
testbid = subset(ebaytrainbid, spl2 == FALSE)

spl3 = sample.split(ebaytrainbuyitnow$sold, SplitRatio = 0.7)
trainBIN = subset(ebaytrainbuyitnow, spl3 == T)
testBIN = subset(ebaytrainbuyitnow, spl3 == F)

trainbid$sold = as.factor(trainbid$sold)
testbid$sold = as.factor(testbid$sold)

set.seed(144)
ebayRF =  randomForest(sold ~., data = trainbid)
testPred = predict(ebayRF, newdata = testbid, type = 'prob')[,2]
ROCRpred = prediction(testPred, testbid$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.8443518

ebayRF$importance # we see that the highly contributing variables are: startprice, condition, storrage, productline, TotalWords, lowstartprice

#remove remaining variables and make a second random forest model
trainbid = trainbid[-c(3,4,5,11,13)]
testbid = testbid[-c(3,4,5,11,13)]

set.seed(3)
ebayRF =  randomForest(sold ~., data = trainbid)
testPredbid = predict(ebayRF, newdata = testbid, type = 'prob')[,2]
ROCRpred = prediction(testPredbid, testbid$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) #0.8428432

trainBIN$sold = as.factor(trainBIN$sold)
testBIN$sold = as.factor(testBIN$sold)

set.seed(144)
ebayRF =  randomForest(sold ~., data = trainBIN)
testPred = predict(ebayRF, newdata = testBIN, type = 'prob')[,2]
ROCRpred = prediction(testPred, testBIN$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.6461538

ebayRF$importance # we see that the variables carrier, color are important, and not so much the lowstartprice

trainBIN = trainBIN[-c(3, 10, 11, 13)]
testBIN = testBIN[-c(3,10,11,13)]

set.seed(144)
ebayRF =  randomForest(sold ~., data = trainBIN)
testPredBIN = predict(ebayRF, newdata = testBIN, type = 'prob')[,2]
ROCRpred = prediction(testPredBIN, testBIN$sold)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.6311218

allPredictions = c(testPredbid, testPredBIN)
allOutcomes = c(as.numeric(as.character(testbid$sold)), as.numeric(as.character(testBIN$sold)))
ROCRpred = prediction(allPredictions, allOutcomes)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.8564029 
predictionsTable = table(allOutcomes, allPredictions >0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('Bid vs BuyItNow', round(accuracy, 4), round(auc, 4)))
# From these analyses we see that separating into biddable and non biddable does not really improve the predictive power

#####################################################################################
# Fifth model: clustering + then predict (without bag of words)
ebaytrain1 = ebaytrain # to call the original dataset later on
ebaytrain = ebaytrain[,-c(1,11,13,14,15,16)] #remove all the variables that do not cotribute significantly

for (i in 3:8) {ebaytrain[,i] = as.numeric(ebaytrain[,i])}

train = subset(ebaytrain, spl == T)
test = subset(ebaytrain, spl == F)

#Normalize the data
library(caret)
preproc = preProcess(train)
trainNorm = predict(preproc, train)
testNorm = predict(preproc, test)

trainNorm$sold = NULL
set.seed(88)
kmeansClust = kmeans(trainNorm, centers=2)
# to check in a few variables how the clusters differ
NonSigCluters = list(Bid = tapply(train$biddable, kmeansClust$cluster, mean), StartPrice = tapply(train$startprice, kmeansClust$cluster, mean),
                     Carrier = tapply(train$carrier, kmeansClust$cluster, mean), Condition = tapply(train$condition, kmeansClust$cluster, mean),
                     Color = tapply(train$color, kmeansClust$cluster, mean), Storage = tapply(train$storage, kmeansClust$cluster, mean),
                     Product = tapply(train$productline, kmeansClust$cluster, mean), TotalWords = tapply(train$TotalWords, kmeansClust$cluster, mean))

train2 = subset(ebaytrain1, spl == T)
carriersInCluster = table(train2$carrier, kmeansClust$cluster) # see that cluster 1 is enriched in AT&T or no carrier whereas custer 2 in Verizone and Unknown
productlineCluster = table(train2$productline, kmeansClust$cluster) # First cluster contains mostly iPads, second cluster contains unknown and iPads mini

library(flexclust)
km.kcca = as.kcca(kmeansClust, trainNorm)
clusterTrain = predict(km.kcca) 
testNorm$sold = NULL
clusterTest = predict(km.kcca, newdata=testNorm)

#for (i in 3:8) {train[,i] = as.factor(train[,i])}
#for (i in 3:8) {test[,i] = as.factor(test[,i])}

#####################
#Now that I finished clustering, I go back to the original databases, with factors as strings
ebaytrain = ebaytrain1[,-c(1,11,13,14,15,16)] 
train = subset(ebaytrain, spl == T)
test = subset(ebaytrain, spl == F)

train1 = subset(train, clusterTrain == 1)
train2 = subset(train, clusterTrain == 2)
test1 = subset(test, clusterTest == 1)
test2 = subset(test, clusterTest == 2)

#predictions for each cluster in train set: logistic regression
logReg1 = glm(sold ~ ., data=train1, family=binomial)
logReg2 = glm(sold ~ ., data=train2, family=binomial)

testPred1 = predict(logReg1, newdata = test1, type="response")
testPred2 = predict(logReg2, newdata = test2, type="response")

# Pooling the predictions
allPredictions = c(testPred1, testPred2)
allOutcomes = c(test1$sold, test2$sold)
ROCRpred = prediction(allPredictions, allOutcomes)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.8758 a modest increase over our previous logistic regression without clustering
predictionsTable = table(allOutcomes, allPredictions >0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('Clusters + logReg', round(accuracy, 4), round(auc, 4)))

#predictions for each cluster in train set: Random Forest
train1$sold = as.factor(train1$sold)
train2$sold = as.factor(train2$sold)
test1$sold = as.factor(test1$sold)
test2$sold = as.factor(test2$sold)

RF1 = randomForest(sold ~ ., data=train1)
RF2 = randomForest(sold ~ ., data=train2)

testPred1 = predict(RF1, newdata = test1, type="prob")[,2]
testPred2 = predict(RF2, newdata = test2, type="prob")[,2]

# Pooling the predictions
allPredictions = c(testPred1, testPred2)
allOutcomes = c(test1$sold, test2$sold)
ROCRpred = prediction(allPredictions, allOutcomes)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) 
predictionsTable = table(allOutcomes, allPredictions >0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('Clusters + RF', round(accuracy, 4), round(auc, 4)))

###############################################################################
# Sixth model: clustering + predict (with bag of words)

newtrain = newtrain[,-c(1,11,13,14,15,16)]
newtrain1 = newtrain

for (i in 3:8) {newtrain[,i] = as.numeric(newtrain[,i])}

train = subset(newtrain, spl == T)
test = subset(newtrain, spl == F)

#Normalize the data
preproc = preProcess(train)
trainNorm = predict(preproc, train)
testNorm = predict(preproc, test)

trainNorm$sold = NULL
set.seed(88)
kmeansClust = kmeans(trainNorm, centers=2)

km.kcca = as.kcca(kmeansClust, trainNorm)
clusterTrain = predict(km.kcca) 
testNorm$sold = NULL
clusterTest = predict(km.kcca, newdata=testNorm)

#predictions for each cluster in train set: Random Forest
train = subset(newtrain1, spl == T)
test = subset(newtrain1, spl == F)
train$sold = as.factor(train$sold)
test$sold = as.factor(test$sold)

train1 = subset(train, clusterTrain == 1)
train2 = subset(train, clusterTrain == 2)
test1 = subset(test, clusterTest == 1)
test2 = subset(test, clusterTest == 2)

set.seed(99)
RF1 = randomForest(sold ~ ., data=train1)
RF2 = randomForest(sold ~ ., data=train2)

testPred1 = predict(RF1, newdata = test1, type="prob")[,2]
testPred2 = predict(RF2, newdata = test2, type="prob")[,2]

# Pooling the predictions
allPredictions = c(testPred1, testPred2)
allOutcomes = c(test1$sold, test2$sold)
ROCRpred = prediction(allPredictions, allOutcomes)
auc = as.numeric(performance(ROCRpred, "auc")@y.values) # 0.8849478  slight improvement
predictionsTable = table(allOutcomes, allPredictions >0.5)
accuracy = (predictionsTable[1,1]+predictionsTable[2,2])/sum(predictionsTable) 
modelsFit = rbind(modelsFit, c('Clusters w/text+ RF, including text variable', round(accuracy, 4), round(auc, 4)))

#Conclusion: the bag of words does not really contribute to the predictive power of our algorithm

######################################################################################################
modelsFit = as.data.frame(modelsFit, stringsAsFactors = FALSE)
names(modelsFit)[1] = 'Model'
for (i in 2:3) {modelsFit[,i] = as.numeric(modelsFit[,i])}
l = modelsFit$Model
modelsFit$Model = factor(modelsFit$Model, levels = l)

#Visualisation
library(ggplot2)
g = ggplot(modelsFit, aes(x=Model, y=Accuracy)) + geom_bar(stat = 'identity', fill = 'dark blue') 
g = g + theme(axis.title.x = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1, size = 15, color = 'black'))
g = g + theme(axis.title.y = element_text(size = 20, vjust = 2), axis.text.y = element_text(size = 15, color = 'black'))
g = g + ggtitle("Accuracy of the Different Predictive Models") +  theme(plot.title=element_text(face="bold", size=20))    
g = g + coord_cartesian(ylim = c(0.70, 0.9)) 

g2 = ggplot(modelsFit, aes(x=Model, y=auc)) + geom_bar(stat = 'identity', fill = 'red') 
g2 = g2 + theme(axis.title.x = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1, size = 15, color = 'black'))
g2 = g2 + theme(axis.title.y = element_text(size = 20, vjust = 2), axis.text.y = element_text(size = 15, color = 'black'))
g2 = g2 + ggtitle("auc for the Different Predictive Models") +  theme(plot.title=element_text(face="bold", size=20))    
g2 = g2 + coord_cartesian(ylim = c(0.70, 1))

carriersClust = data.frame(carriersInCluster[,1], carriersInCluster[,2])
colnames(carriersClust) = c('Cluster1', 'Cluster2')
carriersClust$carrier = rownames(carriersClust)
rownames(carriersClust) = NULL
library("reshape2")
carriersClust = melt(carriersClust, id.vars = 'carrier')
g3 = ggplot(data = carriersClust, aes(x = carrier, y=value)) + geom_bar(stat = 'identity', color = 'black', fill = 'orange') 
g3 = g3 +facet_grid(variable~.)
g3 = g3 + theme(axis.title.x = element_blank(), axis.text.x = element_text(angle = 45, size = 15, color = 'black'))
g3 = g3 + ylab('Number of Products') + theme(axis.title.y = element_text(size = 20, vjust = 2), axis.text.y = element_text(size = 15, color = 'black'))
g3 = g3 + ggtitle("Distribution of Carriers in the Different Clusters") +  theme(plot.title=element_text(face="bold", size=15))    
g3 = g3 + theme(strip.text.y = element_text(size = 15))

productlineCluster = data.frame(productlineCluster[,1], productlineCluster[,2])
colnames(productlineCluster) = c('Cluster1', 'Cluster2')
productlineCluster$prodline = rownames(productlineCluster)
rownames(carriersClust) = NULL
productlineCluster = melt(productlineCluster, id.vars = 'prodline')
g4 = ggplot(data = productlineCluster, aes(x = prodline, y=value)) + geom_bar(stat = 'identity', color = 'black', fill = 'light blue')
g4 = g4 +facet_grid(variable~.)
g4 = g4 + theme(axis.title.x = element_blank(), axis.text.x = element_text(angle = 45, size = 15, color = 'black'))
g4 = g4 + ylab('Number of Products') + theme(axis.title.y = element_text(size = 20, vjust = 2), axis.text.y = element_text(size = 15, color = 'black'))
g4 = g4 + ggtitle("Distribution of Products in the Different Clusters") +  theme(plot.title=element_text(face="bold", size=15))    
g4 = g4 + theme(strip.text.y = element_text(size = 15))

modelsOrd = modelsFit[order(modelsFit$auc, modelsFit$Accuracy, decreasing = TRUE),]
modelsOrd = modelsOrd[1:5,]
write.csv(modelsOrd, './EDXKaggle/Top5Models.csv', row.names=FALSE)

library(png)
png(filename = "./EDXKaggle/AccuracyModels.png", width = 480, height = 480, units = "px")
print(g)
dev.off()

png(filename = "./EDXKaggle/aucModels.png", width = 480, height = 480, units = "px")
print(g2)
dev.off()

png(filename = "./EDXKaggle/CarriersInClusters.png", width = 480, height = 480, units = "px")
print(g3)
dev.off()

png(filename = "./EDXKaggle/ProductsInClusters.png", width = 480, height = 480, units = "px")
print(g4)
dev.off()

