(function ($) {
  "use strict";
  var charts = {};
  var detailRequest;
  var detailTrigger;

  function chartData(name) {
    var node = document.querySelector(
      '.md-chart-data[data-chart="' + name + '"]',
    );
    if (!node) return [];
    try {
      return JSON.parse(node.textContent || node.innerText || "[]");
    } catch (error) {
      return [];
    }
  }

  function drawChart(id, dataName, keys, colors, bar, integerCounts, rateMode) {
    var element = document.getElementById(id);
    var data = chartData(dataName);
    if (element) {
      var previous=$(element).data("dashboard-chart");
      if (previous && previous.raphael) previous.raphael.remove();
      $(element).off();
      $(element).empty(); $(element).removeClass("dashboard-chart-empty");
    }
    if (!element || !window.Morris) return;
    var labels;
    try {
      labels = JSON.parse(element.getAttribute("data-labels") || "[]");
      if (rateMode && element.hasAttribute("data-rate-labels")) labels = JSON.parse(element.getAttribute("data-rate-labels"));
    } catch (error) {
      labels = keys;
    }
    if (
      !data.length ||
      !data.some(function (point) {
        return keys.some(function (key) {
          return point[key] !== null && point[key] !== undefined;
        });
      })
    ) {
      element.textContent = element.getAttribute("data-empty") || "";
      element.className += " dashboard-chart-empty";
      return;
    }
    var options = {
      element: element,
      data: data,
      xkey: "Month",
      ykeys: keys,
      labels: labels,
      lineColors: colors,
      barColors: colors,
      resize: false,
      hideHover: "auto",
      parseTime: false,
      smooth: false,
      gridTextColor: "#526477",
      gridLineColor: "#e6ebf1",
      gridTextSize: 12,
      pointSize: 3,
      lineWidth: 2,
      barSizeRatio: 0.55,
      yLabelFormat: function (value) {
        if (value === null || value === undefined) return "—";
        var number = Number(value);
        if (number !== 0 && Math.abs(number) < 0.01) return number < 0 ? ">−0,01" : "<0,01";
        return number.toLocaleString("vi-VN", { maximumFractionDigits: rateMode ? 1 : 2 }) + (rateMode ? "%" : "");
      },
    };
    options.hoverCallback = function (index, chartOptions, content) {
      var point = data[index];
      if (point.Coverage !== undefined) content += '<div class="morris-hover-point">' + (dataName === 'warning-trend' ? 'DN so sánh hợp lệ / được phân: ' : 'Có dữ liệu / được phân: ') + point.Coverage + ' / ' + point.Expected + '</div>';
      return content;
    };
    if (rateMode) { options.ymin = 0; options.ymax = 100; }
    if (integerCounts && !rateMode) {
      var maxCount = data.reduce(function (max, point) {
        return keys.reduce(function (value, key) {
          return Math.max(value, Number(point[key]) || 0);
        }, max);
      }, 0);
      options.ymin = 0;
      options.ymax = Math.max(4, Math.ceil(maxCount / 4) * 4);
      options.numLines = 5;
    }
    var chart = bar ? new Morris.Bar(options) : new Morris.Line(options);
    $(element).data("dashboard-chart",chart);
    charts[id] = chart;
  }

  $(function () {
    var progressTable = $("#dashboard-progress-enterprises");
    if (progressTable.length && $.fn.DataTable) {
      var initial = JSON.parse(document.getElementById("dashboard-progress-data").textContent);
      var progressUrl = new URL(window.location.href);
      var savedLength = Number(progressUrl.searchParams.get("progressLength")) || initial.pageSize;
      if ([10, 25, 50, 100].indexOf(savedLength) < 0) savedLength = initial.pageSize;
      var savedStart = (Math.max(1, Number(progressUrl.searchParams.get("page")) || 1) - 1) * savedLength;
      if (!Number.isSafeInteger(savedStart) || savedStart < 0 || savedStart > 2147483647 || savedStart % savedLength !== 0) savedStart = 0;
      var savedSearch = "";
      var searchKeyUrl = new URL(progressUrl.href);
      ["page", "progressLength", "progressStart", "progressSearch"].forEach(function (key) { searchKeyUrl.searchParams.delete(key); });
      searchKeyUrl.searchParams.sort();
      var searchStorageKey = "dashboard-progress-search:" + searchKeyUrl.pathname + "?" + searchKeyUrl.searchParams.toString();
      try { savedSearch = (sessionStorage.getItem(searchStorageKey) || "").slice(0, 250); } catch (error) { /* Storage may be disabled. */ }
      var lastResult = { recordsTotal: initial.total, recordsFiltered: initial.total, data: initial.data };
      var lastState = { start: initial.start, length: initial.pageSize, search: "" };
      var failedState;
      var progressRequest;
      var latestDraw;
      function loadProgressState(api, state) {
        api.page.len(state.length).search(state.search).page(state.start / state.length).draw(false);
      }
      function textCell(cell, value) { $(cell).text(value || "—"); }
      function labelCell(cell, label, color) {
        $(cell).empty().append($("<span>", { "class": "label label-" + color }).text(label));
      }
      var progressApi = progressTable.DataTable({
        serverSide: true,
        processing: true,
        ordering: false,
        lengthChange: true,
        pageLength: initial.pageSize,
        lengthMenu: [10, 25, 50, 100],
        displayStart: initial.start,
        searchDelay: 350,
        data: initial.data,
        deferLoading: initial.total,
        drawCallback: function () {
          var api = this.api(), info = api.page.info();
          $("#progress-enterprise-count").text(info.recordsDisplay.toLocaleString("vi-VN") + " " + progressTable.attr("data-enterprises"));
          var url = new URL(window.location.href);
          url.searchParams.set("page", Math.floor(info.start / info.length) + 1);
          url.searchParams.delete("progressStart");
          url.searchParams.set("progressLength", info.length);
          url.searchParams.delete("progressSearch");
          try { sessionStorage.setItem(searchStorageKey, api.search()); } catch (error) { /* Storage may be disabled. */ }
          window.history.replaceState(window.history.state, "", url.href);
        },
        language: {
          processing: "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>",
          searchPlaceholder: "Tên doanh nghiệp, mã số thuế, địa bàn…",
          search: "Tìm kiếm:",
          lengthMenu: "Hiển thị _MENU_ doanh nghiệp",
          info: "Hiển thị _START_–_END_ / _TOTAL_ doanh nghiệp",
          infoEmpty: "Hiển thị 0 doanh nghiệp",
          infoFiltered: "(lọc từ _MAX_ doanh nghiệp)",
          emptyTable: "Chưa có doanh nghiệp trong phạm vi đã chọn.",
          paginate: { first: "Đầu", last: "Cuối", next: "Sau", previous: "Trước" },
          aria: { paginate: { first: "Trang đầu", last: "Trang cuối", next: "Trang sau", previous: "Trang trước" } },
          zeroRecords: "Không tìm thấy doanh nghiệp. Hãy thử từ khóa khác hoặc thay đổi bộ lọc."
        },
        ajax: function (request, callback, settings) {
          latestDraw = request.draw;
          if (progressRequest) progressRequest.abort();
          $("#progress-enterprise-error").prop("hidden", true);
          progressRequest = $.ajax({ url: progressTable.attr("data-url"), type: "GET", dataType: "json",
            data: { draw: request.draw, start: request.start, length: request.length, "search[value]": request.search.value }
          })
            .done(function (response) {
              if (request.draw !== latestDraw) return;
              lastResult = response;
              lastState = { start: request.start, length: request.length, search: request.search.value };
              failedState = null;
              callback(response);
            })
            .fail(function (xhr, status) {
              if (status === "abort" || request.draw !== latestDraw) return;
              failedState = { start: request.start, length: request.length, search: request.search.value };
              $("#progress-enterprise-error").prop("hidden", false);
              var api = new $.fn.dataTable.Api(settings);
              api.page.len(lastState.length).search(lastState.search).page(lastState.start / lastState.length);
              $(settings.nTableWrapper).find(".dataTables_filter input").val(lastState.search);
              $(settings.nTableWrapper).find(".dataTables_length select").val(lastState.length);
              callback($.extend({}, lastResult, { draw: request.draw }));
            });
        },
        // Dynamic values are inserted with jQuery.text rather than interpreted as HTML.
        columnDefs: [{ targets: "_all", render: function (value, type) { return type === "display" ? "" : value; } }],
        columns: [
          { data: "Name", createdCell: function (cell, value, row) {
            var url = new URL(progressTable.attr("data-detail-url"), window.location.href);
            url.searchParams.set("enterpriseId", row.EnterpriseId);
            $(cell).empty().append($("<a>", { "class": "dashboard-detail-link", href: url.href }).text(value), "<br>", $("<small>").text(row.TaxCode));
          } },
          { data: "WardName", createdCell: textCell },
          { data: "DataImported", createdCell: function (cell, value) {
            labelCell(cell, progressTable.attr(value ? "data-has-data" : "data-no-data"), value ? "success" : "default");
          } },
          { data: "MissingMetricCodes", createdCell: function (cell, value) {
            if (value) textCell(cell, value);
            else $(cell).empty().append($("<span>", { "class": "text-green" }).text(progressTable.attr("data-complete")));
          } },
          { data: "MetricConflict", createdCell: function (cell, value) {
            if (value) labelCell(cell, progressTable.attr("data-review"), "warning");
            else textCell(cell, "—");
          } },
          { data: "FileAnyType", createdCell: function (cell, value, row) { textCell(cell, value ? (row.FileLate ? "Có · Trễ" : "Có tệp") : "Chưa có"); } },
          { data: "Reason", createdCell: function (cell, value, row) {
            if (value && value.trim()) $(cell).empty().append($("<details>").append($("<summary>", { "aria-label": "Giải trình " + row.Name }).text("Xem"), $("<p>").text(value)));
            else textCell(cell, "—");
          } }
        ]
      });
      if (savedLength !== initial.pageSize || savedStart !== initial.start || savedSearch) {
        loadProgressState(progressApi, { start: savedStart, length: savedLength, search: savedSearch });
      }
      $("#progress-enterprise-retry").on("click", function () {
        if (failedState) loadProgressState(progressApi, failedState);
      });
    }
    var resizeTimer;
    $(window).off("resize.dashboardCharts").on("resize.dashboardCharts",function () {
      window.clearTimeout(resizeTimer);
      resizeTimer=window.setTimeout(function () {
        Object.keys(charts).forEach(function (id) { if ($("#"+id).is(":visible")) charts[id].resizeHandler(); });
      },100);
    });
    if ($.fn.select2) {
      $(".management-dashboard .dashboard-filter-toolbar select").each(function () {
        if (this.id === "enterpriseId") {
          var select = $(this);
          select.select2({ width:"100%",language:"vi",allowClear:false,
            ajax: { url:select.attr("data-options-url"),dataType:"json",delay:250,
              data:function (params) { return { q:params.term || "",page:params.page || 1,reportType:select.attr("data-report-type") || null }; },
              processResults:function (data,params) { if (!params.page || params.page === 1) data.results.unshift({ id:"all",text:"Tất cả doanh nghiệp" }); return data; }
            }
          });
          return;
        }
        $(this).select2({
          width: "100%",
          language: "vi",
          allowClear: false,
          minimumResultsForSearch: $(this).closest(".dashboard-filter-primary").length ? Infinity : 0,
        });
      });
      $(".management-dashboard .dashboard-filter-toolbar select").each(function () {
        var label = $(this).closest("form").find('label[for="' + this.id + '"]');
        if (label.length) {
          label.attr("id", this.id + "-label");
          $(this).next(".select2-container").find('[role="combobox"]')
            .attr("aria-labelledby", this.id + "-label");
        }
      });
    }
    $(".management-dashboard .dashboard-filter-toolbar").each(function () {
      var form = this;
      $(form).find('[type="submit"]').each(function () {
        $(this).data("dashboard-submit-html", $(this).html());
      });
      $(form).on("submit", function () {
        $(form).attr("aria-busy", "true");
        $(form).find('[type="submit"]').prop("disabled", true)
          .html('<i class="fa fa-circle-o-notch fa-spin" aria-hidden="true"></i> Đang tải…');
      });
    });
    $(window).on("pageshow.dashboardFilters", function () {
      $(".management-dashboard .dashboard-filter-toolbar").removeAttr("aria-busy")
        .find('[type="submit"]').prop("disabled", false).each(function () {
          $(this).html($(this).data("dashboard-submit-html"));
        });
    });
    $(".dashboard-chart-toggle").each(function () {
      var selected = $(this).attr("data-mode") === "count";
      $(this).toggleClass("active", selected).attr("aria-pressed", String(selected));
    });
    $("#dashboard-enterprise-detail").on("hidden.bs.modal", function () {
      if (detailRequest) detailRequest.abort();
      if (detailTrigger) detailTrigger.focus();
    });
    $(".management-dashboard").on("click", ".dashboard-detail-link", function (event) {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      detailTrigger = this;
      if (detailRequest) detailRequest.abort();
      var modal = $("#dashboard-enterprise-detail");
      modal.find(".modal-body").attr("aria-busy", "true").text("Đang tải…"); modal.modal("show");
      detailRequest = $.get(this.href).done(function (html) {
        modal.find(".modal-body").attr("aria-busy", "false").html(html);
      }).fail(function (xhr, status) {
        if (status !== "abort") modal.find(".modal-body").attr("aria-busy", "false")
          .text("Không tải được dữ liệu. Đóng cửa sổ và chọn lại doanh nghiệp để thử lại.");
      });
    });
    $(".dashboard-chart-toggle").on("click", function () {
      var id=$(this).attr("data-chart-id"), rate=$(this).attr("data-mode") === "rate";
      if (id === "receipt-overview-chart") drawChart(id,"receipt-overview",rate ? ["Type1Rate","Type2Rate","Type3Rate"] : ["Type1","Type2","Type3"],["#3c8dbc","#00a65a","#f39c12"],true,true,rate);
      else drawChart(id,"observation-trend",rate ? ["Rate"] : ["Value","Files"],["#00a65a","#3c8dbc"],false,true,rate);
      $(this).addClass("active").attr("aria-pressed", "true")
        .siblings(".dashboard-chart-toggle").removeClass("active").attr("aria-pressed", "false");
    });
    drawChart(
      "receipt-overview-chart",
      "receipt-overview",
      ["Type1", "Type2", "Type3"],
      ["#3c8dbc", "#00a65a", "#f39c12"],
      true,
      true,
    );
    drawChart(
      "analysis-trend-chart",
      "analysis-trend",
      ["Value"],
      ["#3c8dbc"],
      false,
    );
    drawChart(
      "warning-trend-chart",
      "warning-trend",
      ["Value"],
      ["#dd4b39"],
      true,
      true,
    );
    drawChart(
      "observation-trend-chart",
      "observation-trend",
      ["Value", "Files"],
      ["#00a65a", "#3c8dbc"],
      false,
      true,
    );
  });
})(jQuery);
