<%--

    The contents of this file are subject to the license and copyright
    detailed in the LICENSE and NOTICE files at the root of the source
    tree and available online at

    http://www.dspace.org/license/

--%>

<%--
  - Display the form to refine the simple-search and dispaly the results of the search
  -
  - Attributes to pass in:
  -
  -   scope            - pass in if the scope of the search was a community
  -                      or a collection
  -   scopes 		   - the list of available scopes where limit the search
  -   sortOptions	   - the list of available sort options
  -   availableFilters - the list of filters available to the user
  -
  -   query            - The original query
  -   queryArgs		   - The query configuration parameters (rpp, sort, etc.)
  -   appliedFilters   - The list of applied filters (user input or facet)
  -
  -   search.error     - a flag to say that an error has occurred
  -   spellcheck	   - the suggested spell check query (if any)
  -   qResults		   - the discovery results
  -   items            - the results.  An array of Items, most relevant first
  -   communities      - results, Community[]
  -   collections      - results, Collection[]
  -
  -   admin_button     - If the user is an admin
  --%>

<%@page import="org.dspace.core.Utils" %>
<%@page import="com.coverity.security.Escape" %>
<%@page import="org.dspace.discovery.configuration.DiscoverySearchFilterFacet" %>
<%@page import="org.dspace.app.webui.util.UIUtil" %>
<%@page import="java.util.HashMap" %>
<%@page import="java.util.ArrayList" %>
<%@page import="org.dspace.discovery.DiscoverFacetField" %>
<%@page import="org.dspace.discovery.configuration.DiscoverySearchFilter" %>
<%@page import="org.dspace.discovery.DiscoverFilterQuery" %>
<%@page import="org.dspace.discovery.DiscoverQuery" %>
<%@page import="org.apache.commons.lang.StringUtils" %>
<%@page import="java.util.Map" %>
<%@page import="org.dspace.discovery.DiscoverResult.FacetResult" %>
<%@page import="org.dspace.discovery.DiscoverResult" %>
<%@page import="org.dspace.content.DSpaceObject" %>
<%@page import="java.util.List" %>
<%@ page contentType="text/html;charset=UTF-8" %>

<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt"
           prefix="fmt" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core"
           prefix="c" %>

<%@ taglib uri="http://www.dspace.org/dspace-tags.tld" prefix="dspace" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="org.dspace.content.Community" %>
<%@ page import="org.dspace.content.Collection" %>
<%@ page import="org.dspace.content.Item" %>
<%@ page import="org.dspace.sort.SortOption" %>
<%@ page import="java.util.Enumeration" %>
<%@ page import="java.util.Set" %>
<%@ page import="org.apache.commons.lang.StringEscapeUtils" %>
<%
    // Get the attributes
    DSpaceObject scope = (DSpaceObject) request.getAttribute("scope");
    String searchScope = scope != null ? scope.getHandle() : "";
    List<DSpaceObject> scopes = (List<DSpaceObject>) request.getAttribute("scopes");
    List<String> sortOptions = (List<String>) request.getAttribute("sortOptions");

    String query = (String) request.getAttribute("query");
    if (query == null) {
        query = "";
    }
    Boolean error_b = (Boolean) request.getAttribute("search.error");
    boolean error = error_b == null ? false : error_b.booleanValue();

    DiscoverQuery qArgs = (DiscoverQuery) request.getAttribute("queryArgs");
    String sortedBy = qArgs.getSortField();
    String order = qArgs.getSortOrder().toString();
    String ascSelected = (SortOption.ASCENDING.equalsIgnoreCase(order) ? "selected=\"selected\"" : "");
    String descSelected = (SortOption.DESCENDING.equalsIgnoreCase(order) ? "selected=\"selected\"" : "");
    String httpFilters = "";
    String spellCheckQuery = (String) request.getAttribute("spellcheck");
    List<DiscoverySearchFilter> availableFilters = (List<DiscoverySearchFilter>) request.getAttribute("availableFilters");
    List<String[]> appliedFilters = (List<String[]>) request.getAttribute("appliedFilters");
    List<String> appliedFilterQueries = (List<String>) request.getAttribute("appliedFilterQueries");
    if (appliedFilters != null && appliedFilters.size() > 0) {
        int idx = 1;
        for (String[] filter : appliedFilters) {
            if (filter == null
                    || filter[0] == null || filter[0].trim().equals("")
                    || filter[2] == null || filter[2].trim().equals("")) {
                idx++;
                continue;
            }
            httpFilters += "&amp;filter_field_" + idx + "=" + URLEncoder.encode(filter[0], "UTF-8");
            httpFilters += "&amp;filter_type_" + idx + "=" + URLEncoder.encode(filter[1], "UTF-8");
            httpFilters += "&amp;filter_value_" + idx + "=" + URLEncoder.encode(filter[2], "UTF-8");
            idx++;
        }
    }
    int rpp = qArgs.getMaxResults();
    int etAl = ((Integer) request.getAttribute("etal")).intValue();

    String[] options = new String[]{"contains", "equals", "authority", "notequals", "notcontains", "notauthority"};

    // Admin user or not
    Boolean admin_b = (Boolean) request.getAttribute("admin_button");
    boolean admin_button = (admin_b == null ? false : admin_b.booleanValue());

    DiscoverResult qResults = (DiscoverResult) request.getAttribute("queryresults");
    List<Item> items = (List<Item>) request.getAttribute("items");
    List<Community> communities = (List<Community>) request.getAttribute("communities");
    List<Collection> collections = (List<Collection>) request.getAttribute("collections");

%>

<c:set var="dspace.layout.head.last" scope="request">
    <script type="text/javascript">
        var jQ = jQuery.noConflict();
        jQ(document).ready(function () {
            jQ("#spellCheckQuery").click(function () {
                jQ("#query").val(jQ(this).attr('data-spell'));
                jQ("#main-query-submit").click();
            });
            jQ("#filterquery")
                .autocomplete({
                    source: function (request, response) {
                        jQ.ajax({
                            url: "<%= request.getContextPath() %>/json/discovery/autocomplete?query=<%= URLEncoder.encode(query,"UTF-8")%><%= httpFilters.replaceAll("&amp;","&") %>",
                            dataType: "json",
                            cache: false,
                            data: {
                                auto_idx: jQ("#filtername").val(),
                                auto_query: request.term,
                                auto_sort: 'count',
                                auto_type: jQ("#filtertype").val(),
                                location: '<%= searchScope %>'
                            },
                            success: function (data) {
                                response(jQ.map(data.autocomplete, function (item) {
                                    var tmp_val = item.authorityKey;
                                    if (tmp_val == null || tmp_val == '') {
                                        tmp_val = item.displayedValue;
                                    }
                                    return {
                                        label: item.displayedValue + " (" + item.count + ")",
                                        value: tmp_val
                                    };
                                }))
                            }
                        })
                    }
                });
        });

        function validateFilters() {
            return document.getElementById("filterquery").value.length > 0;
        }
    </script>
</c:set>

<dspace:layout titlekey="jsp.search.title">

    <div class="search-main">


        <%
            boolean brefine = false;

            List<DiscoverySearchFilterFacet> facetsConf = (List<DiscoverySearchFilterFacet>) request.getAttribute("facetsConfig");
            Map<String, Boolean> showFacets = new HashMap<String, Boolean>();

            for (DiscoverySearchFilterFacet facetConf : facetsConf)
            {
                if (qResults != null) {
                    String f = facetConf.getIndexFieldName();
                    List<FacetResult> facet = qResults.getFacetResult(f);
                    if (facet.size() == 0) {
                        facet = qResults.getFacetResult(f + ".year");
                        if (facet.size() == 0) {
                            showFacets.put(f, false);
                            continue;
                        }
                    }
                    boolean showFacet = false;
                    for (FacetResult fvalue : facet) {
                        if (!appliedFilterQueries.contains(f + "::" + fvalue.getFilterType() + "::" + fvalue.getAsFilterQuery())) {
                            showFacet = true;
                            break;
                        }
                    }
                    showFacets.put(f, showFacet);
                    brefine = brefine || showFacet;
                }
            }
            if (brefine)
            {
        %>
        <div class="search-facet">
            <h3><fmt:message key="jsp.search.facet.refine"/></h3>

            <%
                for (DiscoverySearchFilterFacet facetConf : facetsConf)
                {
                    String f = facetConf.getIndexFieldName();
                    if (!showFacets.get(f))
                        continue;
                    List<FacetResult> facet = qResults.getFacetResult(f);
                    if (facet.size() == 0) {
                        facet = qResults.getFacetResult(f + ".year");
                    }
                    int limit = facetConf.getFacetLimit() + 1;

                    String fkey = "jsp.search.facet.refine." + f;
            %>
            <div class="accordion-body">

                <div class="accordion-header collapsed" data-toggle="collapse" href="#facet_<%= f %>" role="button" aria-expanded="false" aria-controls="facet_<%= f %>">
                    <span><fmt:message key="<%= fkey %>"/></span>
                </div> <!-- acordion header -->
                <div class="collapse" id="facet_<%= f %>">

                    <ul class="accordion-content">
                        <%
                            int idx = 1;
                            int currFp = UIUtil.getIntParameter(request, f + "_page");
                            if (currFp < 0) {
                                currFp = 0;
                            }
                            for (FacetResult fvalue : facet)
                            {
                                if (idx != limit && !appliedFilterQueries.contains(f + "::" + fvalue.getFilterType() + "::" + fvalue.getAsFilterQuery())) {
                        %>
                        <li>
                            <a href="<%= request.getContextPath()
																										+ (!searchScope.equals("")?"/handle/"+searchScope:"")
																				+ "/simple-search?query="
																				+ URLEncoder.encode(query,"UTF-8")
																				+ "&amp;sort_by=" + sortedBy
																				+ "&amp;order=" + order
																				+ "&amp;rpp=" + rpp
																				+ httpFilters
																				+ "&amp;etal=" + etAl
																				+ "&amp;filtername="+URLEncoder.encode(f,"UTF-8")
																				+ "&amp;filterquery="+URLEncoder.encode(fvalue.getAsFilterQuery(),"UTF-8")
																				+ "&amp;filtertype="+URLEncoder.encode(fvalue.getFilterType(),"UTF-8") %>"
                               title="<fmt:message key="jsp.search.facet.narrow"><fmt:param><%=fvalue.getDisplayedValue() %></fmt:param></fmt:message>">
                                <%= StringUtils.abbreviate(fvalue.getDisplayedValue(), 36) %>
                            </a>
                            <a class="number-a" href="#"><%= fvalue.getCount() %></a>

                        </li>
                        <%
                                    idx++;
                                }
                                if (idx > limit) {
                                    break;
                                }
                            }
                            if (currFp > 0 || idx == limit) {
                        %>
                        <li class="list-group-item"><span style="visibility: hidden;">.</span>
                            <% if (currFp > 0) { %>
                            <a class="pull-left" href="<%= request.getContextPath()
                                                                                                                + (!searchScope.equals("")?"/handle/"+searchScope:"")
                                                                                    + "/simple-search?query="
                                                                                    + URLEncoder.encode(query,"UTF-8")
                                                                                    + "&amp;sort_by=" + sortedBy
                                                                                    + "&amp;order=" + order
                                                                                    + "&amp;rpp=" + rpp
                                                                                    + httpFilters
                                                                                    + "&amp;etal=" + etAl
                                                                                    + "&amp;"+f+"_page="+(currFp-1) %>"><fmt:message key="jsp.search.facet.refine.previous"/></a>
                            <% } %>
                            <%
                                if (idx == limit)
                                {
                            %>
                            <a href="<%= request.getContextPath()
                                                                                                    + (!searchScope.equals("")?"/handle/"+searchScope:"")
                                                                                    + "/simple-search?query="
                                                                                    + URLEncoder.encode(query,"UTF-8")
                                                                                    + "&amp;sort_by=" + sortedBy
                                                                                    + "&amp;order=" + order
                                                                                    + "&amp;rpp=" + rpp
                                                                                    + httpFilters
                                                                                    + "&amp;etal=" + etAl
                                                                                    + "&amp;"+f+"_page="+(currFp+1) %>">
                                <span class="pull-right"><fmt:message key="jsp.search.facet.refine.next"/></span>
                            </a>
                            <%
                                }
                            %>
                        </li>
                        <%
                            }
                        %>
                    </ul>
                </div> <!-- div colapse -->

            </div> <!-- accordion-body -->

            <%
                }
            %> <!-- loop facet -->

        </div> <!-- search facet -->
        <% } %>

        <div class="search-filter">
            <h3>Filtro para busca</h3>
            <div class="search-element searchfilter">
                <div class="accordion-header" data-toggle="collapse" href="#searchAccordion" role="button"
                     aria-expanded="true" aria-controls="searchAccordion">
                    <span><fmt:message key="jsp.search.results.searchin"></fmt:message></span>
                </div>
                <div id="searchAccordion">
                    <form action="simple-search" method="get">

                        <input type="hidden" value="<%= rpp %>" name="rpp"/>
                        <input type="hidden" value="<%= sortedBy %>" name="sort_by"/>
                        <input type="hidden" value="<%= order %>" name="order"/>

                        <!-- Primeira linha -->
                        <div class="grid-col">
                            <div>
                                <select name="location" id="tlocation" class="field-s w100">
                                        <%
                                            if (scope == null) {
                                                // Scope of the search was all of DSpace.  The scope control will list
                                                // "all of DSpace" and the communities.
                                        %>
                                            <%-- <option selected value="/">All of DSpace</option> --%>
                                            <option selected="selected" value="/"><fmt:message
                                                    key="jsp.general.genericScope"/></option>
                                            <% } else {
                                            %>
                                            <option value="/"><fmt:message key="jsp.general.genericScope"/></option>
                                            <% }
                                                for (DSpaceObject dso : scopes) {
                                            %>
                                            <option value="<%= dso.getHandle() %>" <%=dso.getHandle().equals(searchScope) ? "selected=\"selected\"" : "" %>>
                                                <%= dso.getName() %>
                                            </option>
                                        <%
                                            }
                                        %>
                                </select>
                            </div>
                            <div>
                                <input type="text" class="field-s w100" id="query" name="query"
                                       value="<%= (query==null ? "" : StringEscapeUtils.escapeHtml(query)) %>"
                                       class="field-s"
                                       placeholder="<fmt:message key="jsp.search.results.searchfor"/>">
                            </div>
                            <div>
                                <button type="submit" class="button-main"><fmt:message key="jsp.general.go"/></button>
                            </div>
                        </div>
                        <br>

                        <!-- filtros já utilizados -->
                        <% if (appliedFilters.size() > 0) { %>


                                        <%
                                            int idx = 1;
                                            for (String[] filter : appliedFilters)
                                            {
                                                boolean found = false;
                                            %>
                                            <div class="grid-colsecond">
                                                <div>
                                                    <select id="filter_field_<%=idx %>" name="filter_field_<%=idx %>" class="field-s w100">
                                                        <%
                                                            for (DiscoverySearchFilter searchFilter : availableFilters) {
                                                                String fkey = "jsp.search.filter." + searchFilter.getIndexFieldName();
                                                        %>
                                                        <option value="<%= searchFilter.getIndexFieldName() %>"<%
                                                            if (filter[0].equals(searchFilter.getIndexFieldName())) {
                                                        %> selected="selected"<%
                                                                found = true;
                                                            }
                                                        %>><fmt:message key="<%= fkey %>"/></option>
                                                        <%
                                                            }
                                                            if (!found) {
                                                                String fkey = "jsp.search.filter." + filter[0];
                                                        %>
                                                        <option value="<%= filter[0] %>" selected="selected"><fmt:message
                                                                key="<%= fkey %>"/></option>
                                                        <%
                                                            }
                                                        %>
                                                    </select>
                                                </div>

                                                <div>
                                                    <select id="filter_type_<%=idx %>" name="filter_type_<%=idx %>" class="field-s w100">
                                                        <%
                                                            for (String opt : options) {
                                                                String fkey = "jsp.search.filter.op." + opt;
                                                        %>
                                                        <option value="<%= opt %>"<%= opt.equals(filter[1]) ? " selected=\"selected\"" : "" %>>
                                                            <fmt:message key="<%= fkey %>"/></option>
                                                        <%
                                                            }
                                                        %>
                                                    </select>
                                                </div>

                                                <div>
                                                    <input type="text" id="filter_value_<%=idx %>" name="filter_value_<%=idx %>"
                                                           value="<%= StringEscapeUtils.escapeHtml(filter[2]) %>" class="field-s w100"/>
                                                </div>
                                                <div>
                                                    <button type="submit" class="button-main-outline"><fmt:message key="jsp.general.go"/></button>
                                                </div>
                                            </div>
                        <%
                                idx++;
                            }
                        %>
                        <% } %>

                        <!-- fim já utilizados -->


                    </form>
                    <hr>
                    <% if (StringUtils.isNotBlank(spellCheckQuery)) {%>
                    <br/>
                    <p class="lead white-font"><fmt:message key="jsp.search.didyoumean"><fmt:param><a class="white-font"
                                                                                                      id="spellCheckQuery"
                                                                                                      data-spell="<%= Utils.addEntities(spellCheckQuery) %>"
                                                                                                      href="#"><%= spellCheckQuery %>
                    </a></fmt:param></fmt:message></p>
                    <% } %>

                    <% if (availableFilters.size() > 0) { %>

                    <form action="simple-search" method="get">

                        <input type="hidden" value="<%= StringEscapeUtils.escapeHtml(searchScope) %>" name="location"/>
                        <input type="hidden" value="<%= StringEscapeUtils.escapeHtml(query) %>" name="query"/>
                        <% if (appliedFilterQueries.size() > 0) {
                            int idx = 1;
                            for (String[] filter : appliedFilters) {
                                boolean found = false;
                        %>
                        <input type="hidden" id="filter_field_<%=idx %>" name="filter_field_<%=idx %>"
                               value="<%= filter[0] %>"/>
                        <input type="hidden" id="filter_type_<%=idx %>" name="filter_type_<%=idx %>"
                               value="<%= filter[1] %>"/>
                        <input type="hidden" id="filter_value_<%=idx %>" name="filter_value_<%=idx %>"
                               value="<%= StringEscapeUtils.escapeHtml(filter[2]) %>"/>
                        <%
                                    idx++;
                                }
                            } %>
                        <!-- Primeira linha -->
                        <div class="grid-colsecond">
                            <div>
                                <select id="filtername" name="filtername" class="field-s w100">
                                    <%
                                        for (DiscoverySearchFilter searchFilter : availableFilters) {
                                            String fkey = "jsp.search.filter." + searchFilter.getIndexFieldName();
                                    %>
                                    <option value="<%= searchFilter.getIndexFieldName() %>"><fmt:message
                                            key="<%= fkey %>"/></option>
                                    <%
                                        }
                                    %>
                                </select>
                            </div>
                            <div>
                                <select id="filtertype" name="filtertype" class="field-s w100">
                                    <%
                                        for (String opt : options) {
                                            String fkey = "jsp.search.filter.op." + opt;
                                    %>
                                    <option value="<%= opt %>"><fmt:message key="<%= fkey %>"/></option>
                                    <%
                                        }
                                    %>
                                </select>
                            </div>
                            <div>

                                <input type="text" id="filterquery" name="filterquery" class="field-s w100"
                                       placeholder="Escolha por"/>
                                <input type="hidden" value="<%= rpp %>" name="rpp"/>
                                <input type="hidden" value="<%= sortedBy %>" name="sort_by"/>
                                <input type="hidden" value="<%= order %>" name="order"/>

                            </div>
                            <div>
                                <button type="submit" class="button-main-outline" type="submit"><fmt:message
                                        key="jsp.search.filter.add"/></button>

                            </div>
                        </div>
                        <!--p class="lead white-font">Did you mean: <b><i><a class="white-font" id="spellCheckQuery" data-spell="sds" href="#"-->
                        </a></i></b></p>

                    </form>

                </div>
                <% } %>

            </div>

            <br/><br/><br/>
            <% if (items.size() > 0) { %>
            <div class="panel panel-info">
                <div class="panel-heading"><fmt:message key="jsp.search.results.itemhits"/></div>
                <dspace:itemlist items="<%= items %>" authorLimit="<%= etAl %>"/>


                <%
                    if (error) {
                %>
                <p align="center" class="submitFormWarn">
                    <fmt:message key="jsp.search.error.discovery"/>
                </p>
                <%
                } else if (qResults != null && qResults.getTotalSearchResults() == 0) {
                %>
                    <%-- <p align="center">Search produced no results.</p> --%>
                <p align="center"><fmt:message key="jsp.search.general.noresults"/></p>
                <%
                } else if (qResults != null) {
                    long pageTotal = ((Long) request.getAttribute("pagetotal")).longValue();
                    long pageCurrent = ((Long) request.getAttribute("pagecurrent")).longValue();
                    long pageLast = ((Long) request.getAttribute("pagelast")).longValue();
                    long pageFirst = ((Long) request.getAttribute("pagefirst")).longValue();

                    // create the URLs accessing the previous and next search result pages
                    String baseURL = request.getContextPath()
                            + (!searchScope.equals("") ? "/handle/" + searchScope : "")
                            + "/simple-search?query="
                            + URLEncoder.encode(query, "UTF-8")
                            + httpFilters
                            + "&amp;sort_by=" + sortedBy
                            + "&amp;order=" + order
                            + "&amp;rpp=" + rpp
                            + "&amp;etal=" + etAl
                            + "&amp;start=";

                    String nextURL = baseURL;
                    String firstURL = baseURL;
                    String lastURL = baseURL;

                    String prevURL = baseURL
                            + (pageCurrent - 2) * qResults.getMaxResults();

                    nextURL = nextURL
                            + (pageCurrent) * qResults.getMaxResults();

                    firstURL = firstURL + "0";
                    lastURL = lastURL + (pageTotal - 1) * qResults.getMaxResults();

                %>
                <%
                    long lastHint = qResults.getStart() + qResults.getMaxResults() <= qResults.getTotalSearchResults() ?
                            qResults.getStart() + qResults.getMaxResults() : qResults.getTotalSearchResults();
                %>

                <div class="pagination-number">

                        <%-- <p align="center">Results <//%=qResults.getStart()+1%>-<//%=qResults.getStart()+qResults.getHitHandles().size()%> of --%>
                    <div class="pagination-number-itens">
                        <ol class="pagination-number-itens">

                            <li class="results">
                                <fmt:message key="jsp.search.results.results">
                                    <fmt:param><%=qResults.getStart() + 1%>
                                    </fmt:param>
                                    <fmt:param><%=lastHint%>
                                    </fmt:param>
                                    <fmt:param><%=qResults.getTotalSearchResults()%>
                                    </fmt:param>
                                    <fmt:param><%=(float) qResults.getSearchTime() / 1000 %>
                                    </fmt:param>
                                </fmt:message>
                            </li>

                            <%
                                if (pageFirst != pageCurrent) {
                            %>
                            <li><a  class="first-pagination" href="<%= prevURL %>">
                                <svg class="color-svg" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                                    <path fill-rule="evenodd" clip-rule="evenodd" d="M9.52858 6.19526C9.78892 5.93491 10.211 5.93491 10.4714 6.19526L13.8047 9.5286C14.0651 9.78894 14.0651 10.2111 13.8047 10.4714L10.4714 13.8047C10.211 14.0651 9.78892 14.0651 9.52858 13.8047C9.26823 13.5444 9.26823 13.1223 9.52858 12.8619L12.3905 10L9.52858 7.13807C9.26823 6.87772 9.26823 6.45561 9.52858 6.19526Z" fill="svg"></path>
                                    <path fill-rule="evenodd" clip-rule="evenodd" d="M2.66667 2C3.03486 2 3.33333 2.29848 3.33333 2.66667V7.33333C3.33333 7.86377 3.54405 8.37247 3.91912 8.74755C4.29419 9.12262 4.8029 9.33333 5.33333 9.33333H13.3333C13.7015 9.33333 14 9.63181 14 10C14 10.3682 13.7015 10.6667 13.3333 10.6667H5.33333C4.44928 10.6667 3.60143 10.3155 2.97631 9.69036C2.35119 9.06523 2 8.21739 2 7.33333V2.66667C2 2.29848 2.29848 2 2.66667 2Z" fill="svg"></path>
                                </svg>
                                <fmt:message key="jsp.search.general.previous"/></a></li>
                            <%
                            } else {
                            %>
                            <li><a  class="first-pagination"><svg class="color-svg" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M9.52858 6.19526C9.78892 5.93491 10.211 5.93491 10.4714 6.19526L13.8047 9.5286C14.0651 9.78894 14.0651 10.2111 13.8047 10.4714L10.4714 13.8047C10.211 14.0651 9.78892 14.0651 9.52858 13.8047C9.26823 13.5444 9.26823 13.1223 9.52858 12.8619L12.3905 10L9.52858 7.13807C9.26823 6.87772 9.26823 6.45561 9.52858 6.19526Z" fill="svg"></path>
                                <path fill-rule="evenodd" clip-rule="evenodd" d="M2.66667 2C3.03486 2 3.33333 2.29848 3.33333 2.66667V7.33333C3.33333 7.86377 3.54405 8.37247 3.91912 8.74755C4.29419 9.12262 4.8029 9.33333 5.33333 9.33333H13.3333C13.7015 9.33333 14 9.63181 14 10C14 10.3682 13.7015 10.6667 13.3333 10.6667H5.33333C4.44928 10.6667 3.60143 10.3155 2.97631 9.69036C2.35119 9.06523 2 8.21739 2 7.33333V2.66667C2 2.29848 2.29848 2 2.66667 2Z" fill="svg"></path>
                            </svg><fmt:message key="jsp.search.general.previous"/></a></li>
                            <%
                                }

                                if (pageFirst != 1) {
                            %>
                            <li><a href="<%= firstURL %>">1</a></li>
                            <li class="disabled"><span>...</span></li>
                            <%
                                }

                                for (long q = pageFirst; q <= pageLast; q++) {
                                    String myLink = "<li><a href=\""
                                            + baseURL;


                                    if (q == pageCurrent) {
                                        myLink = "<li class=\"active\"><a>" + q + "</a></li>";
                                    } else {
                                        myLink = myLink
                                                + (q - 1) * qResults.getMaxResults()
                                                + "\">"
                                                + q
                                                + "</a></li>";
                                    }
                            %>

                            <%= myLink %>

                            <%
                                }

                                if (pageTotal > pageLast) {
                            %>
                            <li class="disabled"><span>...</span></li>
                            <li><a href="<%= lastURL %>"><%= pageTotal %>
                            </a></li>
                            <%
                                }
                                if (pageTotal > pageCurrent) {
                            %>
                            <li><a href="<%= nextURL %>"><fmt:message key="jsp.search.general.next"/></a></li>
                            <%
                            } else {
                            %>
                            <li class="disabled"><span><fmt:message key="jsp.search.general.next"/></span></li>
                            <%
                                }
                            %>
                        </ol>

                    </div>
                    <!-- give a content to the div -->
                </div>
                <% } %>
            </div>
            <% } %>
        </div>




    </div>














</dspace:layout>