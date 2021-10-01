mkdir -p raw_tlc_data
cat setup_files/raw_data_urls.txt | xargs -n 1 -P 6 wget -c -P raw_tlc_data/
