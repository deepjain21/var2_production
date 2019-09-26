#===================Loading Libraries========================================================================
library("dplyr")
library("RSelenium") # library for rbinding the the selenium driver with R
library("rvest") # library for parsing the html doc
library("tesseract") #library for image processing

source("D:/utility_codes/utility_codes_v1.R")

hsi_stock_list <- read.table("D:/utility_codes/scrapping/hsi_contract_range_scrapping/input/HSI-Stocks.txt")
hsi_stock_list <- as.character(hsi_stock_list$V1)
hsi_stock_list <- hsi_stock_list[hsi_stock_list!="HSI"]
hsi_stock_list

remote_driver <- RSelenium::remoteDriver(port = 4444,browserName = "chrome")
remote_driver$open()
remote_driver$refresh()
remote_driver$getStatus()

remote_driver$navigate("https://contract.ibkr.info/v3.10/index.php")
stock_tab_element <- remote_driver$findElement(using = "id","stk")
stock_tab_element$clickElement()
stock_tab_element$screenshot(display = TRUE)

webpage <- read_html(remote_driver$getPageSource()[[1]])

exchange_df <- webpage %>% 
  html_nodes("#exchange") %>% 
  html_children() %>% 
  html_text() %>% 
  data_frame(exchange_name = .)


exchange_df2 <- exchange_df %>% 
  dplyr::mutate(`list_position` = 1:nrow(exchange_df)) %>% 
  dplyr::mutate(`exchange_link` = paste0("#exchange > option:nth-child(",`list_position`,")"))


hsi_exchange_link <- exchange_df2$exchange_link[exchange_df2$exchange_name == "Stock Exchange of Hong Kong (SEHK)"]
increment_value_list <- list()
for (hsi_stock in hsi_stock_list) {
  
  print(paste0("stock_name : ",hsi_stock))
  
  exchange_element <- remote_driver$findElement(using = "css selector",value = hsi_exchange_link)
  exchange_element$clickElement()
  exchange_element$screenshot(display=TRUE)
  
  symbol_element <- remote_driver$findElement(using = "id",value = "symbol")
  symbol_element$clickElement()
  symbol_element$clearElement()
  symbol_element$sendKeysToElement(list(hsi_stock,key="enter"))
  symbol_element$screenshot(display = TRUE)
  
  search_element <- remote_driver$findElement(using="xpath",'//*[@id="bottomSearch"]/div/div/input[1]')
  search_element$clickElement()
  
  window_handles <- remote_driver$getWindowHandles()
  parent_window <- window_handles[[1]]
  child_window <- window_handles[[2]]
  rselenium_switch_window(remote_driver,child_window)
  remote_driver$screenshot(display = TRUE)
  Sys.sleep(1)
  
  child_webpage <- read_html(remote_driver$getPageSource()[[1]])
  child_result_tbl <- child_webpage %>% 
    html_nodes(".resultsTbl") %>% 
    html_table(fill = TRUE) %>% 
    data.frame()
  nrow(child_result_tbl)
  
  if (nrow(child_result_tbl) == 0) {
    
    print("IB block the code")
    image_element <- child_webpage %>% 
      html_nodes("img") %>%
      html_attr("src")
    image_text <- str_split(image_element,"=")[[1]][2]
    
    
    validation_input_element <- remote_driver$findElement(using="xpath",'/html/body/form/input[1]')
    validation_input_element$clickElement()
    validation_input_element$clearElement()
    validation_input_element$sendKeysToElement(list(image_text,key="enter"))
    remote_driver$screenshot(display = TRUE)
    Sys.sleep(1)
    
  }
      
  
  stock_details <- remote_driver$findElement(using="xpath",value = '//*[@id="refreshForm"]/table/tbody/tr[4]/td[1]/a' )
  stock_details$clickElement()
  window_handles <- remote_driver$getWindowHandles()
  details_window <- window_handles[[3]] 
  rselenium_switch_window(remote_driver,details_window)  
  remote_driver$screenshot(display = TRUE)
  Sys.sleep(1)
  
  details_webpage <- read_html(remote_driver$getPageSource()[[1]])
  details_result_tbl <- details_webpage %>% 
    html_nodes(".table") %>% 
    html_table(fill=TRUE) 
  print(class(details_result_tbl))
  if(length(details_result_tbl) == 0){
    
    print("IB block the code in details screen")
    image_element <- details_webpage %>% 
      html_nodes("img") %>%
      html_attr("src")
    image_text <- str_split(image_element,"=")[[1]][2]
    
    
    validation_input_element <- remote_driver$findElement(using="xpath",'/html/body/form/input[1]')
    validation_input_element$clickElement()
    validation_input_element$clearElement()
    validation_input_element$sendKeysToElement(list(image_text,key="enter"))
    remote_driver$screenshot(display = TRUE)
    Sys.sleep(1)
    
    details_webpage <- read_html(remote_driver$getPageSource()[[1]])
  }
  
  
    increment_value <- details_webpage %>% 
    html_node("#contractSpecs > table:nth-child(7) > tbody > tr:nth-child(8) > td > center > table > tbody > tr:nth-child(2) > td:nth-child(2)") %>% 
    html_text()
  print(increment_value)
  increment_value_list[[hsi_stock]] <- as.numeric(increment_value)
  
  remote_driver$closeWindow()
  rselenium_switch_window(remote_driver,child_window)
  remote_driver$closeWindow()
  rselenium_switch_window(remote_driver,parent_window)
  remote_driver$screenshot(display = TRUE)
  
  Sys.sleep(1)
    
}

length(increment_value_list)
namerows(increment_value_list)


increment_df <- data.frame("stock_symbol" = as.character(names(increment_value_list)),
                           "increment" = as.numeric(unlist(increment_value_list)))

write.csv(increment_df,"D:/utility_codes/scrapping/hsi_contract_range_scrapping/ouput/hsi_increment.csv",
          row.names = FALSE)
  
