#!/usr/bin/env ruby

require 'simple_bioc'
require 'nokogiri'

files=Dir["data/*.xml"].reject{ |f| File.zero?(f) }

yesdata_strings=['Summary level results for all analyses are available on OSF',
                 'available for download from the KoreanChip consortium website',
                 #CHARGE
                 'available for download through the CHARGE repository',
                 'available from the CHARGE dbGaP',
                 'available for download on the CHARGE dbGaP',
                 'Genotypes and Phenotypes (dbGaP) under the CHARGE acquisition number',
                 'Summary association results of the combined GWAS meta-analysis have been submitted for full download to the CHARGE',
                 'The complete summary statistics and results files are available through ImmPort',
                 # MAGIC
                 'publicly deposited the summary results statistics on line at the Meta-Analyses of Glucose and Insulin-related traits Consortium (MAGIC) website',
                 'available at NIH GRASP',
                 'The data presented in this study are openly available in [Zenodo] at',
                 'available at https://www.decode.com/summarydata/',
                 'available for download and browsing via the RGC’s COVID-19 Results Browser',
                 'Summary statistics with the results from the CUD GWAS is available on the iPSYCH',
                 'http://bcac.ccge.medschl.cam.ac.uk',
                 'available for download on the Psychiatric Genomic Consortium ',
                 'Full meta-analysis summary statistics are available at the European Genome-phenome Archive under the collection ID EGAS00001003278',
                 "deposited in the IEU Open GWAS platform",
                 "available at the National Bioscience Database Center",
                 # figshare
                 "available via figshare",
                 'can be accessed at figshare.com',
                 "available on figshare",
                 "downloaded at figshare",
                 'can be accessed upon publication using doi: https://doi.org/10.6084/m9.figshare.11303372',
                 'available in 10.6084/m9.figshare.8066999',
                 "https://figshare.com/s/60b39c8308e2a9986089", # GWAS summary statistics for this study (https://figshare.com/s/60b39c8308e2a9986089) are open access
                 # zenodo
                 'are available for download from Zenodo',
                 'Summary statistics from our discovery and sensitivity GWAS was deposited at Zenodo',
                 'ummary level data from the meta-analyses, can be found online at https://doi.org/10.5281/zenodo.5643551.',
                 'All data are available for unrestricted use through the GEFOS consortium',
                 'publicly available at the GEFOS website',
                 'are openly available in dbGaP',
                 "The full summary level association data from the trans-ancestry meta-analysis for each lipid trait from this report are available through dbGaP",
                 'Summary statistics from the GWAS have been deposited to ORA-Data',
                 'All data is available in the Center for Neurogenomics and informatics (NGI) website',
                 # Biobank Japan
                 'deposited in the National Bioscience Database Center (https://humandbs.biosciencedbc.jp/en/)',
                 'Summary GWAS estimates for the T2D meta-analysis and bivariate summary data are publicly available',
                 'he datasets generated during and/or analysed during the current study are available in the International Stroke Genetics Consortium repository',
                 'Full summary statistics relating to the GWAS meta-analysis has been deposited at the European Genome-phenome Archive (EGA)',
                 'Summary level data from the exome array component of this project will be made available at the DIAGRAM consortium',
                 'Summary statistics of all analyses are available at https://www.broadinstitute.org/collaboration/giant/',
                 "http://bcac.ccge.medschl.cam.ac.uk/bcacdata/", # manually verified
                 "The datasets generated for this study can be found in Mendeley Data",
                 "https://www.med.unc.edu/pgc/download-results/",
                 "summary statistics are available in LD Hub",
                 'The summary statistics are available for download the iPSYCH and at the PGC download sites',
                 'GWAS summary statistics of the 42 diseases are publicly available at our website'
                ].map { |t| t.downcase }
nodata_strings=['gwas summary statistics is available to researchers upon writing to the corresponding authors',
                'Full summary statistics for the genome-wide meta-analysis can be accessed from https://github.com/genomicsITER/PFgenetics', # just describes how to apply
                'https://drive.google.com/file/d/1Rq7AGPFnERlsy1qPZylQEVmYc6OvMwQj/view?usp=sharing', # does not exist
                'broad.cvdi.org', # domain does not exist
                '10.5281/zenodo.1194289', # top 10,834 only
                # 23andme always incomplete
                'dataset-request@23andme.com',
                'apply.research@23andMe.com',
                'will be made available through 23andMe to qualified researchers',
                'https://researchers.23andme.org/collaborations',
                "summary statistics for the first 10,000",
                # polite refusals / available from authors - this != freely available, and experience is that requests often not fulfilled.
                'Data availability statement: No data are available.',
                'No additional data are available.',
                'available for purchase',
                "available from authors",
                'data can be requested',
                'GWAS results of discovery analysis of all the seven RBC traits can be requested',
                'Requests for data can be made to the corresponding author.',
                'will be available to any qualified researcher',
                'will be available through the UK Biobank Access',
                'not publicly available due to ethical issues',
                'available to bona fide researchers',
                'No source data is published alongside the paper.',
                'Requests for access to the GWAS summary statistics results',
                'will be deposited in dbGaP following an embargo',
                # others
                'Summary statistics from the GWAS analyses is deposited at GWAS central', # cannot extract full data
                'GWAS summary statistics will be available through NIAGADS', # p values only
                'Complete summary GWAS results from this paper will be made available at the time of publication at https://www.lothianbirthcohort.ed.ac.uk/content/gwas-summary-data', # 404
                "phs000796", # access request
                'http://2anp.2.vu/GWAS_SLE_Thailand.', # 404s
                "http://www.ccmb.res.in/staff/chandak/data.html", # not found
                'The raw data supporting the conclusion of this article will be made available by the authors'].map { |t| t.downcase }

# 24 files get classified as both. manually reviewed, and mostly these are not sharers. But set those true sharers here
manual_shared_files=%w(data/31053729.xml data/30367059.xml data/34754074.xml data/33949668.xml data/34450027.xml data/34045744.xml data/33082346.xml data/32390946.xml)
data_exists=manual_shared_files
data_missing=[]
dbgap=[]
dbgap_hidden=%w(phs000094 phs000796 phs001549) # data need to be applied for and/or doesn't include summary data

def include_any?(wanted, refset)
  refset.any? { |s| wanted.include?(s) }
end

## dbgap analyses data
dbgap_analyses=[]
f=File.open('Ftp_Table_of_Contents.xml')
while l= f.gets do
  # File.readlines().each do |l|
  m=l.match /<directory name="analyses"/
  next if m.nil? # skip unless this is a new analyses directory
  m=l.match /(phs\d+)/
  next if m.nil? # skip if no phs identifier
  l2=f.gets # get next line
  dbgap_analyses.push(m[0]) if l2 =~ /directory-content/ # keep if it has some content
end

(files - manual_shared_files).each do |f|
  toprint=[]
  ## Parse with a file name (path)
  collection = SimpleBioC::from_xml(f)
  document=collection.documents[0]
  document.passages.each_with_index do |passage,i|
    next if %w(REF TABLE table fig_caption table_caption).include?passage.infons["section_type"] # don't print bibliography, tables
    t=passage.text.downcase
    if (t.include?("summary") & t.include?("data") & t.include?("available") & t.include?("download") ) |
       (t.include?("GWAS summary statistics") & t.include?("available") & t.include?("JENGER")) |
       (t.include?("full genome-wide summary-level results") & t.include?("available")) |
       include_any?( t, yesdata_strings )
      data_exists.push(f)
    elsif (t.include?("available") & t.include?("reasonable request")) |
          (t.include?("available") & t.include?("on request")) |
          (t.include?("available") & t.include?("by application")) |
          (t.include?("available") & t.include?("upon application")) |
          (t.include?("can be shared upon request")) |
          include_any?( t, nodata_strings )
      data_missing.push(f)
    # dbgap - require additional keyword to avoid catching people *using* dbgap as oppose to *depositing* there
    elsif (include_any?(t, ['available','deposited', 'posted']) & t.include?("dbgap"))
      # find pattern like phs000179.v5.p2
      m=passage.text.match /(phs\d+)/ # leave off the version bit, because versions can get updated
      if m.nil?
        toprint.push( f + " : " + passage.text )
      else
        ok=dbgap_analyses.include?( m[1] )
        dbgap.push(m[1]) if ok
        data_exists.push(f) if ok
        data_missing.push(f) unless ok
      end
    elsif t.include?("data") & t.include?("availability") & (passage.text.length < 50) # looks like a heading
      toprint.push( f + " : " + document.passages[i+1].text )
    else # don't know
      #"summary statistics", "summary data", "dbGaP", "IEU", "freely available", "deposited on", "zenodo".
      toprint.push( f + " : " + passage.text ) if ( t.include?("summary statistics") | t.include?("deposited") | t.include?("available") |
                                                    t.include?("dbgap") | t.include?("zenodo") | t.include?("figshare") ) &
                                                  (passage.text.length < 500 )
    end
  end
  # manually scan output to learn yes/no phrases
  puts toprint unless data_exists.include?(f) | data_missing.include?(f)
  # should be empty
  # puts toprint if data_exists.include?(f) & data_missing.include?(f)
end

## manual corrections
data_missing = data_missing - manual_shared_files
data_exists = data_exists - data_missing
data_exists = data_exists.uniq

puts ""
puts "data found: #{data_exists.length}"
puts "data missing: #{data_missing.length}"
puts "data missing and found (hopefully empty): #{(data_missing & data_exists).length}"
puts "unknown: #{files.length - data_exists.length - data_missing.length}"

File.open("data_found.txt", "w+") { |f| f.puts(data_exists) }
File.open("data_notfound.txt", "w+") { |f| f.puts(data_missing) }
File.open("data_confused.txt", "w+") { |f| f.puts(data_missing & data_exists) }
File.open("data_dbgap.txt", "w+") { |f| f.puts(dbgap) }
## positive matches
## The summary statistics of our genome-wide association studies are available at the Human Genetic Variation Database (Accession ID: HGV0000013).
##
## negative matches
## The online version contains supplementary material available at 10.1038/s41598-021-82003-y.
## Due to the confidential nature of the genetic data and cognitive test scores of participants, it is not possible to publically share the data on which our analysis was based. Generation Scotland (GS) data is available on request to: access@generationscotland.org, with further information available from http://www.ed.ac.uk/generation-scotland. Each application requires the completion of a data and materials transfer agreement, the conditions of which be determined on a case by case basis. GS has Research Tissue Bank status, and the GS Access Committee reviews applications to ensure that they comply with legal requirements, ethics and participant consent. UK Biobank data is available for health related research on request to: access@ukbiobank.ac.uk, with further information relating to data access available from http://www.ukbiobank.ac.uk/register-apply. The English Longitudinal Study of Ageing data is available on request to: n.rogers@ucl.ac.uk, with further information regarding data access available from https://www.elsa-project.ac.uk.
## data/29317602.xmlData are available to qualified researchers on a cost-recovery basis via online application processes, accessible via www.gsaccess.org and www.ukbiobank.ac.uk/register-apply/. The code used in these analyses is available on request from the lead author.
##
## tofix - read next line
## data/31784582.xmlData availability
## data/29317602.xmlData and code availability
## data/34047840.xmlAvailability of data and material
