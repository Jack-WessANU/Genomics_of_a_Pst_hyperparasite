# GO Gene Set Enrichment
## TOPGO

install.packages("tidyverse")
install.packages("lintr")
install.packages("lattice")
install.packages("DOSE")

if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install("topGO")
BiocManager::install("Rgraphviz")

library(DOSE)
library(tidyverse)
library(topGO)
library(lintr)
library(lattice)
library(dplyr)
library(Rgraphviz)


# Loading Data
# create GO background mapping
# using dataframe "penx7.csv" with two columns, gene name and GO terms
gene_to_go_mapping <- readMappings(file = "penx7.csv", sep = ";", IDsep = ",")

# get background gene list
# using dataframe "pst_wheat_genome_removed_penx_inplantavsinvitro.csv" with two columns, gene name and LFC value

IPvsIV <-  read.csv("pst_wheat_genome_removed_penx_inplantavsinvitro.csv", header = TRUE)
geneNames <- IPvsIV$Column1

geneNames
# select genes of interest
# Basically this is subsetting down genes based on whether they are significantly upregulated, maybe go higher than 1 LFC but lets see
myInterestingGenes <- subset(IPvsIV, adj.P.Val < 0.05 & logFC > 1)$Column1


# create selection and gene list object
geneList <- factor(as.integer(geneNames %in% myInterestingGenes)) 
names(geneList) <- geneNames
str(geneList)

View(geneList)
# create topgo object
my_go_data <- new("topGOdata",
                  ontology    = "BP",
                  allGenes    = geneList,
                  annot       = annFUN.gene2GO,
                  gene2GO     = gene_to_go_mapping,
                  nodeSize    = 5) # nodesize is min number of genes in GO_term
my_go_data


sigGenes(my_go_data) # see sig DE genes


## Enrichment Tests
# use fisher for gene set number enrichment (not using gene values)
result_weight_fisher <- runTest(object = my_go_data, algorithm = "weight01", statistic = "fisher") # result object

# summarise results
result_weight_output <- GenTable(object    = my_go_data, weight_fisher = result_weight_fisher,
                                 orderBy   = "weight_fisher",
                                 topNodes  = length(score(result_weight_fisher)))

# multiple testing correction (may not be necessary)
result_weight_output$weight_fisher_adjusted <- p.adjust(p = result_weight_output$weight_fisher, method = c("BH")) 

# P-value distribution from Fisher test
ggplot(result_weight_output, aes(x = as.numeric(weight_fisher))) + geom_histogram()


# Create map of sig GO terms
par(cex = 0.35) # change font size
showSigOfNodes(my_go_data, score(result_weight_fisher), firstSigNodes = 5, useInfo = 'all') #firstSigNodes selects how many sig GO_terms

# Genes in GO term stored in topGO object
GO_mapped <- genesInTerm(my_go_data) 
genes

## Plotting genes in sig GO terms
# get sig GO terms

sig_terms <- result_weight_output[as.numeric(result_weight_output$weight_fisher) < 0.05,] # or fisher adjusted values

sig_terms

# Code to generate a dotplot of enriched GO terms, with Gene Ratio (meaning number of significant genes within an individual GO term) as the x axis and GO term as the y axis. The dot size is relative to the total number of significant genes in the term and its colour
# reflects the significance of the term overall (Fisher test)
theme_update(text = element_text(size=18))

ggplot(sig_terms, aes(x = Significant/Annotated, y = reorder(Term,Significant/Annotated))) + geom_point(aes(size = Significant, color = weight_fisher_adjusted), binaxis = "y") + xlim(0, 1.0) + labs(y= "GO term", x = "Gene ratio", size = "# Significant Genes", colour = "Significance")+ggtitle("Hyperparasitic growth")

# get genes in sig go terms
sig_genes <- data.frame()
for(go_term in sig_terms$GO.ID){
  sig_gene <- data.frame(gene = GO_mapped[go_term], GO.ID = go_term)
  names(sig_gene)[1] <- "Column1"
  sig_genes <- rbind(sig_genes, sig_gene)
}



sig_terms_genes <- right_join(sig_terms, sig_genes, by = "GO.ID") # merge genes with result object above

# associate LFC with sig genes
sig_LFC <- right_join(IVvsIP, sig_terms_genes, by = "Column1")

# order by most sig GO term
sig_LFC <- sig_LFC[order(as.numeric(sig_LFC$weight_fisher)),]
sig_LFC$Term <- factor(sig_LFC$Term , levels = rev(unique(sig_LFC$Term )))

sig_terms_genes


# plot LFC
# use "GO.ID" if GO "Term" is not unique

ggplot(sig_LFC, aes(x = logFC, y = Term, fill = as.numeric(weight_fisher))) + geom_violin() + 
  theme_bw() + geom_vline(xintercept = 0, colour = "grey") +
  scale_fill_gradient(low = "red", high = "white")
