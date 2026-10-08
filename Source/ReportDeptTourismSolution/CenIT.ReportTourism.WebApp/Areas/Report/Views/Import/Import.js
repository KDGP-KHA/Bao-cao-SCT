var _DataImportActionURLs = {
    DataImport_GetData: "/Report/Import/Get"
};
var _tableDataImport;

$(document).ready(function() {
    initTableDataImport();
    initSearchEnterpriseSelect2();
});

$(document).on("click", "a.js-view-data-report", function(e) {
    e.preventDefault();
    e.stopPropagation();

    var url = $(this).attr("href");
    var modalId = "modal_ViewDataImport";
    $("#" + modalId).remove();

    var modal = $(
        '<div id="' + modalId + '" class="modal fade" tabindex="-1" role="dialog" data-backdrop="static">' +
        '<div class="modal-dialog modal-xlg" role="document"><div class="modal-content"></div></div></div>');
    $("#ModalContent").append(modal);

    $.ajax({ url: url, type: "GET", cache: false }).done(function(html) {
        var content = html;
        if (typeof html === "string" && _isJson(html)) {
            var response = JSON.parse(html);
            content = '<div class="modal-header bg-primary"><button type="button" class="close" data-dismiss="modal">&times;</button><h4 class="modal-title">Xem dữ liệu báo cáo</h4></div>' +
                '<div class="modal-body"><div class="alert alert-warning">' + (response.message || "Không thể tải dữ liệu báo cáo.") +
                '</div></div><div class="modal-footer"><button type="button" class="btn btn-danger" data-dismiss="modal">Đóng</button></div>';
        }
        modal.find(".modal-content").html(content);
        modal.modal("show");
    }).fail(function() {
        modal.find(".modal-content").html(
            '<div class="modal-header bg-danger"><button type="button" class="close" data-dismiss="modal">&times;</button><h4 class="modal-title">Xem dữ liệu báo cáo</h4></div>' +
            '<div class="modal-body"><div class="alert alert-danger">Không thể tải dữ liệu báo cáo. Vui lòng thử lại.</div></div>' +
            '<div class="modal-footer"><button type="button" class="btn btn-danger" data-dismiss="modal">Đóng</button></div>');
        modal.modal("show");
    }).always(function() {
        $("#loader").removeClass("show pageload-loading").css("display", "none");
    });
});

function initTableDataImport() {
    _tableDataImport = $("#DataImports").DataTable({
        "Responsive": true,
        "language": {
            "processing":
                "<div class='overlay custom-loader-background'><i class='fa fa-cog fa-spin custom-loader-color'></i></div>"
        },
        "order": [[0, "desc"]],
        "lengthChange": true,
        "processing": true,
        "serverSide": true,
        "ajax":
        {
            "url": _DataImportActionURLs.DataImport_GetData,
            "type": "POST",
            "dataType": "JSON",
            "data": {
                "EnterpriseIds": function() {
                    return $("#SearchDataReport select#ListEnterpriseId").val() != null &&
                        $("#SearchDataReport select#ListEnterpriseId").val().length > 0
                        ? $("#SearchDataReport select#ListEnterpriseId").val()
                        : "";
                },
                "FromMonth": function() { return $("#SearchDataReport #FromMonth").val(); },
                "ToMonth": function() { return $("#SearchDataReport #ToMonth").val(); },
                "TypeBusinessIds": function() {
                    return $("#SearchDataReport select#ListTypeBusinessId").val() != null &&
                        $("#SearchDataReport select#ListTypeBusinessId").val().length > 0
                        ? $("#SearchDataReport select#ListTypeBusinessId").val()
                        : "";
                },
            }
        },
        "columns": [
            {
                "data": "",
                "defaultContent": "1",
                "render": function(data, type, row, meta) {
                    return meta.row + 1;
                }
            },
            {
                "data": "EnterpriseName",
                "defaultContent": ""
            },
            {
                "data": "ForMonth",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    if (data != null) {
                        return moment(data).format("MM/YYYY");
                    } else {
                        return "";
                    }
                }
            },
            {
                "data": "TypeReportName",
                "defaultContent": ""
            },
            {
                "data": "CreatedBy",
                "defaultContent": ""
            },
            {
                "data": "CreatedDate",
                "defaultContent": "",
                "render": function(data, type, row, meta) {
                    if (data != null) {
                        return moment(data).format("HH:mm:ss DD/MM/YYYY");
                    } else {
                        return "";
                    }
                }
            },
            {
                "data": "ReportId",
                "style": "width:100px;",
                "orderable": false,
                "render": function(data, type, row, meta) {
                    var html = "";
                    if (type === "display") {
                        if (row.CanDelete) {
                            html += _renderButton(true,
                                "EditReport",
                                "fa fa-pencil btn bg-navy btn-form",
                                "/Report/Import/Edit?enterpriseId=" +
                                row.EnterpriseId +
                                "&onMonth=" +
                                moment(row.ForMonth).format("YYYY-MM-DD") +
                                "&typeReport=" + row.TypeReport,
                                "",
                                "Chỉnh sửa báo cáo",
                                1024);
                        }

                        // Màn xem dùng modal riêng. Cơ chế modal chung đôi khi chỉ
                        // tạo backdrop khi response view được tải chậm/lỗi.
                        html += _renderButton(false,
                            "ViewDataImport",
                            "fa fa-eye btn btn-primary btn-form js-view-data-report",
                            "/Report/Import/View?enterpriseId=" +
                            row.EnterpriseId +
                            "&onMonth=" +
                            moment(row.ForMonth).format("YYYY-MM-DD") +
                            "&typeReport=" + row.TypeReport,
                            "",
                            "Xem dữ liệu báo cáo",
                            "1024px");

                        //html += _renderButton(false,
                        //    "DownloadSignedDoc",
                        //    "fa fa-cloud-download btn bg-teal btn-form",
                        //    "/Report/Import/DownloadSignedDoc?enterpriseId=" +
                        //    row.EnterpriseId +
                        //    "&onMonth=" +
                        //    moment(row.ForMonth).format("YYYY-MM-DD"),
                        //    "",
                        //    "Tải báo cáo đã ký số");

                        if (row.CanDelete) {
                            html += _renderButton(true,
                                "DeleteDataImport",
                                "fa fa-trash-o btn btn-danger btn-form",
                                "/Report/Import/Delete?enterpriseId=" +
                                row.EnterpriseId +
                                "&onMonth=" +
                                moment(row.ForMonth).format("YYYY-MM-DD"),
                                "",
                                "Xoá");
                        }
                    }
                    return html;
                }
            }
        ]
    });
    _tableDataImport.on("draw",
        function() {
            $("a[data-modal-id='DownloadSignedDoc']").each(function(idx, ele) {
                var href = $(ele).attr("href");
                $(ele).data("href", href);
                $(ele).attr("href", "javascript:void(0);");
                $(ele).on("click",
                    function(e) {
                        var url = $(this).data("href");
                        $.ajax({
                            type: "GET",
                            url: url,
                            success: function(response) {
                                if (typeof response != "undefined" && response.status) {
                                    window.location = response.downloadPath;
                                } else if (typeof response != "undefined" && !response.status) {
                                    eval(response.message);
                                }
                            }
                        });
                    });
            });
        });
}

function DataImport_OnProcessSuccess(response, formId) {
    if (response.status != undefined) {
        if (!response.status) {
            eval(response.message);
            return;
        }
        $("#ModalContent #modal_" + formId).modal("hide");
        $("#ModalContent #modal_" + formId).on("hidden.bs.modal",
            function() {
                if (response.status != undefined) {
                    eval(response.message);
                    _tableDataImport.ajax.reload(null, true);
                    $("#ActionArea").load("/Report/Import/ViewAction");
                    response.status = undefined;
                }
            });
    } else {
        $("#ModalContent #modal_" + formId + " #bodyForm").html(response);
    }
}

function OnChangeCombo(cbb, eleName) {
    $(eleName).val($(cbb).children("option:selected").text());
}

function initSearchEnterpriseSelect2() {
    var $select = $("#SearchDataReport select#ListEnterpriseId");
    if ($select.length === 0) return;

    $select.select2({
        placeholder: "-- Chọn hoặc tìm kiếm doanh nghiệp --",
        allowClear: true,
        language: "vi",
        width: "100%",
        ajax: {
            url: "/Report/Import/SearchEnterprisesSelect2",
            dataType: "json",
            delay: 300,
            data: function (params) {
                return {
                    q: params.term || "",
                    typeBusiness: "",
                    page: params.page || 1
                };
            },
            processResults: function (data, params) {
                params.page = params.page || 1;
                return {
                    results: data.results,
                    pagination: {
                        more: data.pagination ? data.pagination.more : false
                    }
                };
            },
            cache: true
        },
        minimumInputLength: 0
    });

    $select.off('select2:open').on('select2:open', function () {
        setTimeout(function () {
            var $searchField = $('.select2-container--open .select2-search__field');
            if ($searchField.length > 0 && !$searchField.val()) {
                $searchField.trigger('input');
            }
        }, 50);
    });
}
