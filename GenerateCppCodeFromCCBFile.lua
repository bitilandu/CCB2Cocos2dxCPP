package.path = package.path .. ';.;'
local filename = FILENAME or arg[1]
local classname = CLASSNAME or arg[2]
local outputfilename = OUTPUTFILNAME or classname
local outputpath = OUTPUTPATH or ''
local dir = DIR or '';

local showlog = showlog or print;

if not filename or filename == "" then
	showlog("No file input...");
	local usage = [[
	Usage: lua %s filename classname
	filename is which ccb file you want to parse
	classname means the [member] and [callback function] belongs to 
	]]
	showlog(string.format(usage, arg[0]));
	return
end

if not classname or classname == "" then
	showlog("class is not given...");
	return
end

-- ��������ƥ���б��������ɵ�h��cpp�ļ��л���CCxxxչ�֣���CCMenu
local smartMatchTypeTbl =
{
	"Menu",		-- �˵�
	"Sprite",	-- ����
	"Layer",	-- ��
	"Node", 	-- �ڵ�
	"MenuItem", -- �˵�ѡ��
	"LabelTTF", -- ��ʾ���ֿؼ�
}


-- ���ҵ�memberVarAssignmentName��Ȼ���stringȡ����
local file = io.open(filename, 'r+b');

if file then
	-- �ȶ��뵽�ڴ�
	local lineData = file:read("*l");
	local varAssignmentFlag = false;
	local varAssignmentTbl = {};
	local menuSelectorTbl = {};
	local controlSelectorTbl = {};
	local lineCnt = 1;
	-- ���ݽ������֣���ccb�ļ���ץȡ��Ҫ������
	while lineData do
		repeat
			if lineData == '' then
				break
			end
			
			-- �ж��Ƿ����б�����
			if varAssignmentFlag then
				local memberName = string.match(lineData, "<string>([%w_]-)</string>");
				if memberName and memberName ~= "" then
					table.insert(varAssignmentTbl, memberName);
				end
				varAssignmentFlag = false;
				break;
			end
			
			-- �ж��Ƿ��� onPress �ؼ��֣����ｨ��ccb�лص�Я��onPressMenu�ȣ�����ץȡ����
			local menuSelector = string.match(lineData, "(onPressMenu[^<]+)");
			if menuSelector then
				table.insert(menuSelectorTbl, menuSelector);
			end
			
			local controlSelector = string.match(lineData, "(onPressControl[^<]+");
			if controlSelector then
				table.insert(controlSelectorTbl, controlSelector);
			end
			
			-- ��鵱ǰ�������Ƿ���memberVarAssignmentName�ֶ�
			if string.find(lineData, "memberVarAssignmentName") then
--				showlog("find", "lineNum is ", lineCnt);
				-- ��һ������Ϊ�󶨱���
				varAssignmentFlag = true;
				
				break;
			end
		until true
		
		lineCnt = lineCnt + 1;
		lineData = file:read("*l");
	end
	
	file:close();
	
	showlog("------------member list:")
	table.foreach(varAssignmentTbl, function(key, value)
		showlog(value);
	end);
	
	showlog("------------menu selector list:");
	table.foreach(menuSelectorTbl, function(key, value)
		showlog(value);
	end);
	
	-- Ԥ��������
	-- ��ʼ������h
	local initCodeTbl = {};
	-- ���ݶ����h
	local memberVariableDeclareTbl = {};
	-- ���ݰ󶨱�cpp
	local memberVariableBindTbl = {};
	-- �˵��ص�����ԭ��h
	local menuSelectorDeclareTbl = {};
	-- �˵��ص���cpp
	local menuSelectorBindTbl = {};
	-- �˵��ص�����ʵ��
	local menuSelectorCallbackTbl = {};
	-- Control�ص�����ԭ��h
	local controlSelectorDeclareTbl = {};
	-- Control�ص���cpp
	local controlSelectorBindTbl = {};
	-- Control�ص�����ʵ��cpp
	local controlSelectorCallbackTbl = {};
	
	-- ��Ա������
	for idx, member in ipairs(varAssignmentTbl) do
		-- ���ɳ�ʼ������
		table.insert(initCodeTbl, string.format("\t\t%s = NULL;\n", member));
		
		-- �ж���ʲô���͵�����
		local varType = 'unKnowType';
		local extension = '';
		for idx, types in ipairs(smartMatchTypeTbl) do
			if string.find(member, types) then
				-- ������Լ���һ���ж��Ƿ�����չ���͵��ж�
				varType = types;
				break;
			end
		end
		table.insert(memberVariableDeclareTbl, string.format('\tcocos2d::%sCC%s* %s;\n', extension, varType, member));
		
		-- ���ɰ󶨳�Ա����
		table.insert(memberVariableBindTbl,
			string.format('\tCCB_MEMBERVARIABLEASSIGNER_GLUE(this, "%s", CC%s*, this->%s);\n',
			member, varType, member));
				
	end
	
	local menuCallBackTpl = [[void %s::%s(CCObject* pSender)
{
	// TODO:
}

]]
	-- �˵��ص���
	for idx, ms in ipairs(menuSelectorTbl) do
		-- ���ɲ˵��ص�����
		table.insert(menuSelectorDeclareTbl, string.format('\tvoid %s(cocos2d::CCObject* pSender);\n', ms));
		-- ���ɲ˵��ص���
		table.insert(menuSelectorBindTbl, 
			string.format('\tCCB_SELECTORRESOLVER_CCMENUITEM_GLUE(this, "%s", %s::%s);\n', ms, classname, ms));
		-- ���ɶ�Ӧ�˵��ص�����ʵ�ִ���
		table.insert(menuSelectorCallbackTbl, string.format(menuCallBackTpl, classname, ms));
	end
	
	local menuCallBackTpl = [[void %s::%s(CCObject* pSender, CCControlEvent event)
{
	// TODO:
}

]]
	-- Control �ص���
	for idx, cs in ipairs(controlSelectorTbl) do
		-- ����control�ص�����
		table.insert(controlSelectorDeclareTbl, string.format('\tvoid %s(cocos2d::CCObject* pSender, cocos2d::extension::CCControlEvent event);\n', cs));
		-- ����control�ص���
		table.insert(controlSelectorBindTbl,
			string.format('\tCCB_SELECTORRESOLVER_CCCONTROL_GLUE(this, "%s", %s::%s);\n', cs, classname, cs));
		-- ���ɶ�Ӧ��ť�ص�����ʵ�ִ���
		table.insert(controlSelectorCallbackTbl, string.format(controlCallBackTbp, classname, ms));
	end
	
	-- �������һ�����滻����ʱ���ݱ��
	local DataCache =
	{
		['$ccbifilename'] = filename .. 'i';		-- ccbi�ļ�����
		['$classname'] = classname;					-- ��ǰ������
		['$CLASSNAME'] = string.upper(classname);	-- �����ļ������궨�������
		['$DATE'] = os.date("%Y-%m-%d %H:%M:%S", os.time());	-- ��ǰ�ļ���������
		['$memberInit'] = table.concat(initCodeTbl);	-- ��ʼ������
		
		['$bindMemberVariableDeclare'] = table.concat(memberVariableDeclareTbl);	-- ��Ա��������
		['$bindMemberVariable'] = table.concat(memberVariableBindTbl);	-- ��Ա������
		
		['$bindMenuSelectorDeclare'] = table.concat(menuSelectorDeclareTbl);	-- �˵��ص���������
		['$bindMenuSelector'] = table.concat(menuSelectorBindTbl);	-- �˵��ص�������
		['$menuSelectorCallback'] = table.concat(menuSelectorCallbackTbl);	-- cpp�в˵��ص���ʵ��
		
		['$bindControlSelectorDeclare'] = table.concat(controlSelectorDeclareTbl); -- control�ص���������
		['$bindControlSelector'] = table.concat(controlSelectorBindTbl); -- cpp�лص�������
		['$controlSelectorCallback'] = table.concat(controlSelectorCallbackTbl); -- cpp�лص�����ʵ�ִ���
	
		['$bindCallfuncSelectorDeclare'] = '';	-- ��ʱδʵ��
		['$bindCallfuncSelector'] = '';	-- ��ʱδʵ��
		['$callfuncSelectorCallback'] = '';	-- ��ʱδʵ��
	}
	
	--[[
		���￪ʼ����ͷ�ļ�
	]]
	showlog(string.format("++++++++++ Generate sample data file [%s.h] ", classname));
	local hfilename = outputpath .. outputfilename .. ".h";

	local hfile = io.open(hfilename, 'w+b');
	if hfile then
		-- ����ͷ�ļ�ģ��
		local templatehfile = io.open(dir .. 'template/template.h', 'r+b');
--		error(tostring(templatehfile))
		local templatehdata = nil;
		if templatehfile then
			templatehdata = templatehfile:read('*a');
			templatehfile:close();
		end
			
		if templatehdata then
			-- ����ͷ�ļ�����
			templatehdata = string.gsub(templatehdata, "($[%w]+)", DataCache);
			
			-- ����ͷ�ļ�
			hfile:write(templatehdata);
		end
		
		hfile:close();
	else
		error(string.format("[%s] can't be opened ...", hfilename));
	end
	
	--[[
		���￪ʼ����cppԴ�ļ�
	]]
	
	showlog(string.format("++++++++++ Generate sample data file [%s.cpp] ", classname));
	local cppfilename = outputpath .. outputfilename .. ".cpp";
	local cppfile = io.open(cppfilename, 'w+b');
	if cppfile then
		-- ����Դ�ļ�ģ��
		local templatecppfile = io.open(dir .. 'template/template.cpp', 'r+b');
		local templatecppdata = nil;
		if templatecppfile then
			templatecppdata = templatecppfile:read('*a');
			templatecppfile:close();
		end
		
		if templatecppdata then
			-- �滻�󶨱�������
			templatecppdata = string.gsub(templatecppdata, "($[%w]+)", DataCache);			
			
			-- ����Դ�ļ�
			cppfile:write(templatecppdata);
		end
		
		cppfile:close();
	else
		error(string.format("[%s] can't be opened ...", hfilename));
	end
	
else
	error(string.format("Open file [%s] failed, please be sure the file is existed and try again later.", filename));
end
