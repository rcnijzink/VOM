function transpmodel(node, onCompleteCallback)
{
   var myobj = { label: "vom_read_input", id: "vom_read_input", href: "vom_read_input.html", target:"basefrm" };
   var tmpNode3 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode3.isLeaf = true; 
   var myobj = { label: "vom_alloc", id: "vom_alloc", href: "vom_alloc.html", target:"basefrm" };
   var tmpNode4 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_open_output", id: "vom_open_output", href: "vom_open_output.html", target:"basefrm" };
   var tmpNode5 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode5.isLeaf = true; 
   var myobj = { label: "vom_open_ncp_output", id: "vom_open_ncp_output", href: "vom_open_ncp_output.html", target:"basefrm" };
   var tmpNode6 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode6.isLeaf = true; 
   var myobj = { label: "vom_get_soilprofile", id: "vom_get_soilprofile", href: "vom_get_soilprofile.html", target:"basefrm" };
   var tmpNode7 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_get_hourly_clim", id: "vom_get_hourly_clim", href: "vom_get_hourly_clim.html", target:"basefrm" };
   var tmpNode8 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_init_vegpar", id: "vom_init_vegpar", href: "vom_init_vegpar.html", target:"basefrm" };
   var tmpNode10 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_daily_init", id: "vom_daily_init", href: "vom_daily_init.html", target:"basefrm" };
   var tmpNode12 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_hourly_init", id: "vom_hourly_init", href: "vom_hourly_init.html", target:"basefrm" };
   var tmpNode13 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_gstom", id: "vom_gstom", href: "vom_gstom.html", target:"basefrm" };
   var tmpNode14 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_subhourly_init", id: "vom_subhourly_init", href: "vom_subhourly_init.html", target:"basefrm" };
   var tmpNode15 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode15.isLeaf = true; 
   var myobj = { label: "vom_rootuptake", id: "vom_rootuptake", href: "vom_rootuptake.html", target:"basefrm" };
   var tmpNode16 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_mqss", id: "vom_mqss", href: "vom_mqss.html", target:"basefrm" };
   var tmpNode17 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode17.isLeaf = true; 
   var myobj = { label: "vom_tissue_water_et", id: "vom_tissue_water_et", href: "vom_tissue_water_et.html", target:"basefrm" };
   var tmpNode18 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_subhourly", id: "vom_subhourly", href: "vom_subhourly.html", target:"basefrm" };
   var tmpNode20 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_add_hourly", id: "vom_add_hourly", href: "vom_add_hourly.html", target:"basefrm" };
   var tmpNode22 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_add_daily", id: "vom_add_daily", href: "vom_add_daily.html", target:"basefrm" };
   var tmpNode23 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_write_hourly", id: "vom_write_hourly", href: "vom_write_hourly.html", target:"basefrm" };
   var tmpNode24 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_check_water", id: "vom_check_water", href: "vom_check_water.html", target:"basefrm" };
   var tmpNode25 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode25.isLeaf = true; 
   var myobj = { label: "vom_write_dayyear", id: "vom_write_dayyear", href: "vom_write_dayyear.html", target:"basefrm" };
   var tmpNode26 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_add_yearly", id: "vom_add_yearly", href: "vom_add_yearly.html", target:"basefrm" };
   var tmpNode28 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_adapt_foliage", id: "vom_adapt_foliage", href: "vom_adapt_foliage.html", target:"basefrm" };
   var tmpNode29 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_adapt_roots", id: "vom_adapt_roots", href: "vom_adapt_roots.html", target:"basefrm" };
   var tmpNode30 = new YAHOO.widget.TextNode(myobj, node, false);
   var myobj = { label: "vom_write_model_output", id: "vom_write_model_output", href: "vom_write_model_output.html", target:"basefrm" };
   var tmpNode31 = new YAHOO.widget.TextNode(myobj, node, false);
   tmpNode31.isLeaf = true; 
     // notify the TreeView component when data load is complete
     onCompleteCallback();
}
