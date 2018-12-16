/*
用于将xmltype转换为json
例：
create table tt3 (c xmltype);
create table tt2 (c clob);
*/
DECLARE
  --测试参数
  xml_req      XMLTYPE;
  document_req dbms_xmldom.DOMDocument;
  node_req     dbms_xmldom.DOMNode;
  vv           VARCHAR2(32000);
  --常量
  type_Element  CONSTANT INTEGER := 0;
  type_Object   CONSTANT INTEGER := 1;
  type_Array    CONSTANT INTEGER := 2;
  type_ArrayEle CONSTANT INTEGER := 3;
  type_ArrayObj CONSTANT INTEGER := 4;
  /*-----------------------------------------------------------------------------------------------
  || 函数名称：fun_appendClob
  || 功能描述：clob添加，因DBMS_LOB.APPEND要求不能为空
  ||----------------------------------------------------------------------------------------------*/
  FUNCTION fun_appendClob(prm_desc IN CLOB, prm_src IN CLOB) RETURN CLOB IS
    rtn_clob CLOB := prm_desc;
  BEGIN
    IF prm_src IS NOT NULL AND DBMS_LOB.GETLENGTH(prm_src) > 0 THEN
      IF prm_desc IS NULL OR DBMS_LOB.GETLENGTH(prm_desc) = 0 THEN
        rtn_clob := prm_src;
      ELSE
        DBMS_LOB.APPEND(rtn_clob, prm_src);
      END IF;
    END IF;
    RETURN rtn_clob;
  END;
  /*-----------------------------------------------------------------------------------------------
  || 函数名称：fun_traversing
  || 功能描述：遍历Node转换为JSON
  ||----------------------------------------------------------------------------------------------*/
  FUNCTION fun_traversing(prm_node     IN DBMS_XMLDOM.DOMNode,
                          prm_jsonType IN INTEGER DEFAULT 1) RETURN ClOB IS
    c_rtnJSON     CLOB;
    v_nodeValue   VARCHAR2(2000);
    v_nodeName    VARCHAR2(30);
    v_nodeType    NUMBER;
    childList     dbms_xmldom.DOMNODELIST;
    childListSize NUMBER;
    childNode     dbms_xmldom.domnode;
    subChildList  dbms_xmldom.DOMNODELIST;
    i_jsonType    INTEGER;
  BEGIN
    v_nodeName := dbms_xmldom.getNodeName(prm_node);
    v_nodeType := dbms_xmldom.getNodeType(prm_node);
    --区分元素类型
    IF v_nodeType = dbms_xmldom.DOCUMENT_NODE THEN
      i_jsonType := type_Object;
    ELSIF v_nodeType = dbms_xmldom.ELEMENT_NODE THEN
      --元素类型，只取名称
      IF prm_jsonType not in (type_ArrayEle, type_ArrayObj) THEN
        --JSONArray的元素，不再重复取名称
        c_rtnJSON := fun_appendClob(c_rtnJSON, '"' || v_nodeName || '":');
        IF prm_jsonType = type_Array THEN
          --JSONArray类型，名称包含子元素名称
          c_rtnJSON := fun_appendClob(c_rtnJSON, '{"');
          c_rtnJSON := fun_appendClob(c_rtnJSON,
                          dbms_xmldom.getNodeName(DBMS_XMLDOM.GETFIRSTCHILD(prm_node)));
          c_rtnJSON := fun_appendClob(c_rtnJSON, '":[');
        END IF;
      END IF;
    ELSIF v_nodeType = dbms_xmldom.TEXT_NODE THEN
      --文本类型，取值，结束退出
      v_nodeValue := DBMS_XMLDOM.GETNODEVALUE(prm_node);
      c_rtnJSON := fun_appendClob(c_rtnJSON, '"' || v_nodeValue || '",');
      RETURN c_rtnJSON;
    END IF;
    --JSONObject用“{”包裹值部分
    IF prm_jsonType in (type_Object, type_ArrayObj) THEN
      c_rtnJSON := fun_appendClob(c_rtnJSON, '{');
    END IF;
    childList     := dbms_xmldom.getChildNodes(prm_node);
    childListSize := dbms_xmldom.getLength(childList);
    --遍历子节点，递归解析
    FOR i IN 0 .. (childListSize - 1) LOOP
      childNode := dbms_xmldom.item(childList, i);
      --子节点和长孙节点均为元素类型，深入解析
      IF dbms_xmldom.getNodeType(childNode) = dbms_xmldom.ELEMENT_NODE AND
         dbms_xmldom.getNodeType(DBMS_XMLDOM.GETFIRSTCHILD(childNode)) =
         dbms_xmldom.ELEMENT_NODE THEN
        --孙子节点，用于判断子节点是否为JSONArray
        subChildList := dbms_xmldom.getChildNodes(childNode);
        --孙子节点不止1个，且首尾同名，视为JSONArray
        --！！！此处未考虑（size = 1）的JSONArray
        IF dbms_xmldom.getLength(subChildList) > 1 and
           dbms_xmldom.getNodeName(DBMS_XMLDOM.GETFIRSTCHILD(childNode)) =
           dbms_xmldom.getNodeName(DBMS_XMLDOM.GETLASTCHILD(childNode)) THEN
          i_jsonType := type_Array;
        ELSIF prm_jsonType = type_Array THEN
          i_jsonType := type_ArrayObj;
        ELSE
          i_jsonType := type_Object;
        END IF;
      ELSIF prm_jsonType = type_Array THEN
        --如果当前为JSONArray，子元素进行特殊处理
        i_jsonType := type_ArrayEle;
      ELSE
        i_jsonType := type_Element;
      END IF;
      c_rtnJSON := fun_appendClob(c_rtnJSON, fun_traversing(childNode, i_jsonType));
    END LOOP;
    --除元素类型，均截去最后一位的“,”
    IF prm_jsonType not in (type_Element, type_ArrayEle) THEN
      c_rtnJSON := regexp_replace(c_rtnJSON, ',$', '');
    END IF;
    --结束符
    CASE prm_jsonType
      WHEN type_Object THEN
        c_rtnJSON := fun_appendClob(c_rtnJSON, '},');
      WHEN type_Array THEN
        c_rtnJSON := fun_appendClob(c_rtnJSON, ']},');
      WHEN type_ArrayObj THEN
        c_rtnJSON := fun_appendClob(c_rtnJSON, '},');
      ELSE
        NULL;
    END CASE;
    --二次截去，较前次增加ArrayObjcet类型
    IF prm_jsonType NOT IN (type_Element, type_ArrayEle, type_ArrayObj) THEN
      c_rtnJSON := regexp_replace(c_rtnJSON, ',$', '');
    END IF;
    RETURN c_rtnJSON;
  END;
BEGIN
  SELECT c INTO xml_req FROM TT3 WHERE ROWNUM = 1;
  document_req := DBMS_XMLDOM.newdomdocument(xml_req);
  node_req     := dbms_xmldom.makenode(document_req);
  vv           := fun_traversing(node_req);
  dbms_output.put_line(vv);
END;